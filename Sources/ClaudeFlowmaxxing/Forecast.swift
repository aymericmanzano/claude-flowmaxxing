import Foundation

/// Relevé des quotas dans le temps : le point d'accès ne donne que la valeur du moment,
/// alors l'app garde chaque changement pour tracer les courbes. Fichier local,
/// ~/Library/Application Support/ClaudeFlowmaxxing/historique.json, 8 jours au plus.
struct UsageSample: Codable, Equatable {
    let t: Date
    let five: Double?
    let seven: Double?
}

enum UsageHistory {
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeFlowmaxxing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("historique.json")
    }()

    static func load() -> [UsageSample] {
        if Demo.on { return demo() }
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([UsageSample].self, from: data) else { return [] }
        return list
    }

    /// Ajoute un relevé s'il diffère du précédent, et oublie ce qui a plus de 8 jours.
    static func append(_ s: UsageSample, to list: [UsageSample]) -> [UsageSample] {
        var out = list.filter { $0.t > Date().addingTimeInterval(-8 * 86400) }
        if let last = out.last, last.five == s.five, last.seven == s.seven { return out }
        out.append(s)
        if !Demo.on, let data = try? JSONEncoder().encode(out) { try? data.write(to: url, options: .atomic) }
        return out
    }

    /// Courbe fictive pour le mode démo, cohérente avec les quotas de démo.
    private static func demo() -> [UsageSample] {
        let now = Date()
        let week: [(Double, Double)] = [(-90, 0), (-80, 6), (-66, 15), (-50, 27), (-30, 40), (-14, 50), (-4, 57)]
        let five: [(Double, Double)] = [(-2.7, 0), (-2.2, 10), (-1.6, 18), (-1.0, 30), (-0.4, 38)]
        var out = week.map { UsageSample(t: now.addingTimeInterval($0.0 * 3600), five: nil, seven: $0.1) }
        out += five.map { UsageSample(t: now.addingTimeInterval($0.0 * 3600), five: $0.1, seven: 59) }
        return out.sorted { $0.t < $1.t }
    }
}

/// Prévision d'une fenêtre de quota (5 heures ou semaine), en pourcentage consommé.
struct Forecast {
    enum Kind { case five, seven }

    let start: Date
    let end: Date
    let now: Date
    let used: Double
    /// Points de la courbe réelle (date, pourcentage consommé), du début de la fenêtre à maintenant.
    let points: [(Date, Double)]
    /// Rythme en points de pourcentage par heure.
    let rate: Double

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var elapsed: TimeInterval { now.timeIntervalSince(start) }
    var remaining: TimeInterval { max(0, end.timeIntervalSince(now)) }
    var left: Double { max(0, 100 - used) }
    /// Consommation qu'aurait un rythme régulier à cet instant.
    var evenUsed: Double { min(100, elapsed / duration * 100) }
    /// Avance (positive) ou retard (négatif) sur le rythme régulier, en points.
    var gap: Double { evenUsed - used }
    var zeroDate: Date? {
        guard rate > 0.0001 else { return nil }
        return now.addingTimeInterval(left / rate * 3600)
    }
    var runsOut: Bool { zeroDate.map { $0 < end } ?? false }
    var lockHours: Double { runsOut ? end.timeIntervalSince(zeroDate!) / 3600 : 0 }
    var usedAtReset: Double { min(100, used + rate * remaining / 3600) }
    /// Part de la fenêtre qu'on peut consommer par jour pour tenir jusqu'au renouvellement.
    var perDay: Double { remaining > 0 ? left / (remaining / 86400) : left }

    /// - Parameters:
    ///   - samples: relevés enregistrés par l'app.
    ///   - costBuckets: coût local par tranche de 15 minutes, pour dessiner la partie de la
    ///     fenêtre antérieure au premier relevé (mise à l'échelle sur le premier pourcentage connu).
    ///   - lastDay: projection sur les dernières 24 heures plutôt que sur toute la fenêtre.
    static func make(_ q: Quota?, kind: Kind, samples: [UsageSample],
                     costBuckets: [(Date, Double)] = [], lastDay: Bool = false, now: Date = Date()) -> Forecast? {
        guard let q, let end = q.resetsAt, end > now else { return nil }
        let length: TimeInterval = kind == .five ? 5 * 3600 : 7 * 86400
        let start = end.addingTimeInterval(-length)
        let elapsedH = now.timeIntervalSince(start) / 3600
        guard elapsedH > 0 else { return nil }

        let known: [(Date, Double)] = samples.compactMap { s in
            guard s.t > start, s.t < now, let v = kind == .five ? s.five : s.seven else { return nil }
            return (s.t, v)
        }
        var pts: [(Date, Double)] = [(start, 0)]
        // Avant le premier relevé : forme donnée par le coût local, calée sur le premier pourcentage.
        let refDate = known.first?.0 ?? now
        let refValue = known.first?.1 ?? q.percent
        let early = costBuckets.filter { $0.0 >= start && $0.0 < refDate }
        let earlyTotal = early.reduce(0) { $0 + $1.1 }
        if earlyTotal > 0, refValue > 0 {
            var acc = 0.0
            for (d, c) in early {
                acc += c
                pts.append((d.addingTimeInterval(15 * 60), acc / earlyTotal * refValue))
            }
        }
        pts += known
        pts.append((now, q.percent))
        // Valeurs croissantes seulement (une fenêtre ne redescend pas avant son renouvellement).
        var peak = 0.0
        pts = pts.map { d, v in peak = max(peak, v); return (d, peak) }

        var rate = q.percent / elapsedH
        if lastDay, kind == .seven, elapsedH > 24 {
            let past = now.addingTimeInterval(-86400)
            if let v = value(at: past, in: pts) { rate = max(0, (q.percent - v) / 24) }
        }
        return Forecast(start: start, end: end, now: now, used: q.percent, points: pts, rate: rate)
    }

    /// Valeur interpolée de la courbe à une date donnée.
    private static func value(at d: Date, in pts: [(Date, Double)]) -> Double? {
        guard let i = pts.firstIndex(where: { $0.0 >= d }) else { return nil }
        if i == 0 { return pts[0].1 }
        let (d0, v0) = pts[i - 1], (d1, v1) = pts[i]
        let span = d1.timeIntervalSince(d0)
        return span > 0 ? v0 + (v1 - v0) * d.timeIntervalSince(d0) / span : v1
    }
}
