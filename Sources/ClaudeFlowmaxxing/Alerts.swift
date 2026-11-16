import Foundation
import UserNotifications

/// Réglages de l'onglet Réglages, rangés dans les préférences de l'app.
enum Settings {
    static let weekAlert = "alerte.semaine"
    static let projectionAlert = "alerte.projection"
    static let fiveAlert = "alerte.5h"
    static let lastDay = "projection.24h"

    static func register() {
        UserDefaults.standard.register(defaults: [weekAlert: true, projectionAlert: true, fiveAlert: true, lastDay: false])
    }
    static func on(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
}

/// Notifications du Mac : seuils de la semaine, semaine qui finit avant le renouvellement,
/// fenêtre de 5 heures presque vide. Chaque alerte part une seule fois par fenêtre
/// (et une fois par jour pour la projection). La permission est demandée à la première alerte.
enum Alerts {
    /// Hors d'une app assemblée (lancement par `swift run`), le centre de notifications plante.
    static var available: Bool {
        !Demo.on && Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    static func check(five: Quota?, seven: Quota?, samples: [UsageSample]) {
        guard available else { return }
        if Settings.on(Settings.weekAlert), let q = seven, let end = q.resetsAt {
            let left = 100 - q.percent
            if let threshold = [10.0, 25, 50].first(where: { left <= $0 }) {
                once("semaine-\(Int(threshold))", window: end) { done in
                    post(L.s("notif.week.title"), L.s("notif.week", Format.pourcent(max(0, left))), done)
                }
            }
        }
        if Settings.on(Settings.projectionAlert),
           let f = Forecast.make(seven, kind: .seven, samples: samples, lastDay: Settings.on(Settings.lastDay)),
           f.runsOut, let zero = f.zeroDate, f.left > 0 {
            let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
            once("projection-\(day)", window: f.end) { done in
                post(L.s("notif.projection.title"),
                     L.s("notif.projection", Format.jour(zero), Format.heure(zero), Format.pourcent1(f.perDay)), done)
            }
        }
        if Settings.on(Settings.fiveAlert), let q = five, let end = q.resetsAt, q.percent >= 90 {
            once("5h", window: end) { done in post(L.s("notif.five.title"), L.s("notif.five"), done) }
        }
    }

    /// Envoie une notification d'essai (`--essai-alerte`).
    static func test() {
        guard available else { Log.write("alerte d'essai : hors d'une app assemblée"); return }
        post(L.s("notif.week.title"), L.s("notif.week", "50%")) { _ in }
    }

    /// Clé arrondie à 10 minutes : la date de renouvellement renvoyée bouge de quelques secondes.
    /// L'alerte n'est notée comme faite qu'une fois affichée : refusée, elle sera retentée.
    private static func once(_ kind: String, window end: Date, _ fire: (@escaping (Bool) -> Void) -> Void) {
        let key = "\(kind)@\(Int(end.timeIntervalSince1970 / 600))"
        let done = UserDefaults.standard.dictionary(forKey: "alertesEnvoyees") as? [String: Double] ?? [:]
        guard done[key] == nil, !pending.contains(key) else { return }
        pending.insert(key)
        fire { ok in
            DispatchQueue.main.async {
                pending.remove(key)
                guard ok else { return }
                let cutoff = Date().addingTimeInterval(-9 * 86400).timeIntervalSince1970
                var list = (UserDefaults.standard.dictionary(forKey: "alertesEnvoyees") as? [String: Double] ?? [:])
                    .filter { $0.value > cutoff }
                list[key] = Date().timeIntervalSince1970
                UserDefaults.standard.set(list, forKey: "alertesEnvoyees")
            }
        }
    }
    private static var pending = Set<String>()

    private static func fallback(_ title: String, _ body: String) -> Bool {
        func q(_ t: String) -> String { t.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "display notification \"\(q(body))\" with title \"\(q(title))\" sound name \"default\""]
        do { try p.run(); p.waitUntilExit() } catch { return false }
        Log.write(p.terminationStatus == 0 ? "alerte envoyée par AppleScript : \(title)" : "alerte : échec AppleScript")
        return p.terminationStatus == 0
    }

    private static func post(_ title: String, _ body: String, _ done: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                // App signée en local : macOS peut refuser le centre de notifications.
                // Repli sur une notification système envoyée par AppleScript.
                Log.write("alerte : centre de notifications refusé\(error.map { " (\($0.localizedDescription))" } ?? ""), repli AppleScript")
                done(fallback(title, body))
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { err in
                Log.write(err == nil ? "alerte envoyée : \(title)" : "alerte : échec (\(err!.localizedDescription))")
                done(err == nil)
            }
        }
    }
}
