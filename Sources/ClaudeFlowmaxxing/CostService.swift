import Foundation

/// Coût estimé à partir des journaux locaux de Claude Code (~/.claude/projects),
/// au tarif public de l'API. Lecture incrémentale : chaque fichier n'est relu qu'à partir
/// de l'endroit où on s'était arrêté.
final class CostService: ObservableObject {
    @Published private(set) var today: Double = 0
    @Published private(set) var projection: Double?
    @Published private(set) var topModel: String?
    @Published private(set) var topShare: Double = 0
    @Published private(set) var week: Double = 0
    @Published private(set) var ready = false

    private struct Entry { let date: Date; let model: String; let cost: Double }

    private let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")
    private let queue = DispatchQueue(label: "claudeflowmaxxing.cost", qos: .utility)
    private var offsets: [String: UInt64] = [:]
    private var seen = Set<String>()
    private var entries: [Entry] = []
    private var timer: Timer?

    init() {
        if Demo.on {
            today = 23.80; projection = 41.10; week = 186.20; topModel = "Opus 5.5"; topShare = 72; ready = true
            return
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        if Demo.on { return }
        queue.async { [weak self] in self?.scan() }
    }

    private func scan() {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-8 * 86400)
        // Parcours récursif : les sous-agents écrivent dans <session>/subagents/*.jsonl.
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys) {
            for case let f as URL in walker where f.pathExtension == "jsonl" {
                let rv = try? f.resourceValues(forKeys: Set(keys))
                guard let mod = rv?.contentModificationDate, mod > cutoff else { continue }
                let size = UInt64(rv?.fileSize ?? 0)
                let start = offsets[f.path] ?? 0
                if size > start { read(f, from: start) }
            }
        }
        entries.removeAll { $0.date < cutoff }
        publish()
    }

    private func read(_ url: URL, from offset: UInt64) {
        guard let h = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? h.close() }
        var pos = offset
        try? h.seek(toOffset: pos)
        var carry = Data()
        // Lecture par blocs de 4 Mo pour garder la mémoire basse sur les gros journaux.
        while true {
            let more: Bool = autoreleasepool {
                guard let chunk = try? h.read(upToCount: 4 << 20), !chunk.isEmpty else { return false }
                carry.append(chunk)
                guard let lastNL = carry.lastIndex(of: 0x0A) else { return true } // ligne pas finie
                let complete = carry[carry.startIndex...lastNL]
                parse(complete)
                pos += UInt64(complete.count)
                carry = Data(carry[carry.index(after: lastNL)...])
                return true
            }
            if !more { break }
        }
        offsets[url.path] = pos
    }

    private static let marker = Data("\"usage\"".utf8)

    private func parse(_ complete: Data) {
        for line in complete.split(separator: 0x0A) where line.range(of: Self.marker) != nil {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  (obj["type"] as? String) == "assistant",
                  let msg = obj["message"] as? [String: Any],
                  let usage = msg["usage"] as? [String: Any],
                  let model = msg["model"] as? String,
                  let ts = (obj["timestamp"] as? String).flatMap(Format.date) else { continue }
            let key = (msg["id"] as? String) ?? (obj["uuid"] as? String) ?? UUID().uuidString
            if seen.contains(key) { continue }
            seen.insert(key)
            guard let cost = Self.cost(model: model, usage: usage) else { continue }
            entries.append(Entry(date: ts, model: model, cost: cost))
        }
    }

    private func publish() {
        let now = Date()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        let todayEntries = entries.filter { $0.date >= startOfDay }
        let todayCost = todayEntries.reduce(0) { $0 + $1.cost }

        // Projection : rythme des deux dernières heures prolongé jusqu'à 23 h.
        var proj: Double?
        let endOfEvening = cal.date(bySettingHour: 23, minute: 0, second: 0, of: now) ?? now
        let hoursLeft = endOfEvening.timeIntervalSince(now) / 3600
        if hoursLeft > 0 {
            let recent = entries.filter { $0.date >= now.addingTimeInterval(-7200) }.reduce(0) { $0 + $1.cost }
            proj = todayCost + recent / 2 * hoursLeft
        }

        let weekEntries = entries.filter { $0.date >= now.addingTimeInterval(-7 * 86400) }
        let weekCost = weekEntries.reduce(0) { $0 + $1.cost }
        var byModel: [String: Double] = [:]
        for e in weekEntries { byModel[Format.nomModele(e.model), default: 0] += e.cost }
        let top = byModel.max { $0.value < $1.value }

        DispatchQueue.main.async {
            self.ready = true
            self.today = todayCost
            self.projection = proj
            self.week = weekCost
            self.topModel = top?.key
            self.topShare = (top != nil && weekCost > 0) ? top!.value / weekCost * 100 : 0
        }
    }

    /// Tarifs publics en dollars par million de jetons : entrée, sortie, lecture de cache.
    static func price(_ model: String) -> (input: Double, output: Double, cacheRead: Double)? {
        let m = model.lowercased()
        if m.contains("fable-5-2") || m.contains("mythos-5-2") { return (8, 40, 0.20) }
        if m.contains("fable") || m.contains("mythos") { return (10, 50, 1.00) }
        if m.contains("opus-5-5") { return (4, 20, 0.20) }
        if m.contains("opus") { return (5, 25, 0.50) }
        if m.contains("sonnet-5-5") { return (2, 10, 0.10) }
        if m.contains("sonnet-5") { return (2, 10, 0.20) }
        if m.contains("sonnet") { return (3, 15, 0.30) }
        if m.contains("haiku-5-5") { return (0.10, 0.50, 0.01) }
        if m.contains("haiku") { return (1, 5, 0.10) }
        return nil
    }

    static func cost(model: String, usage: [String: Any]) -> Double? {
        guard let p = price(model) else { return nil }
        func n(_ k: String, in d: [String: Any] = usage) -> Double { (d[k] as? NSNumber)?.doubleValue ?? 0 }
        let input = n("input_tokens")
        let output = n("output_tokens")
        let cacheRead = n("cache_read_input_tokens")
        var write5m = 0.0, write1h = 0.0
        if let cc = usage["cache_creation"] as? [String: Any] {
            write5m = n("ephemeral_5m_input_tokens", in: cc)
            write1h = n("ephemeral_1h_input_tokens", in: cc)
        } else {
            write5m = n("cache_creation_input_tokens")
        }
        var total = input * p.input + output * p.output + cacheRead * p.cacheRead
            + write5m * p.input * 1.25 + write1h * p.input * 2
        if (usage["speed"] as? String) == "fast" { total *= 2 }
        return total / 1_000_000
    }
}
