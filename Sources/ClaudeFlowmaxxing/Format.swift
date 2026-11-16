import AppKit

/// Journal minimal dans ~/Library/Logs/ClaudeFlowmaxxing.log (jamais de jeton).
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/ClaudeFlowmaxxing.log")
    static func write(_ s: String) {
        let line = "\(Date()) \(s)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

enum Format {
    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// En français, montant sans espace avant le symbole : « 229,84$ », « 3,20€ ».
    /// Dans les autres langues, l'usage local : « $229.84 », « 229,84 $ ».
    static func montant(_ v: Double, symbole: String) -> String {
        if L.isFrench {
            return (decimal.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)) + symbole
        }
        let f = NumberFormatter()
        f.locale = Locale(identifier: L.lang)
        f.numberStyle = .currency
        f.currencySymbol = symbole
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v) + symbole
    }

    static func pourcent(_ v: Double) -> String {
        "\(Int(v.rounded()))%"
    }

    /// « 4 h 38 min », « 5 j 20 h », « 12 min »
    static func dureeAvant(_ date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSinceNow / 60))
        let jours = minutes / 1440
        let heures = (minutes % 1440) / 60
        let mins = minutes % 60
        if jours > 0 { return L.s("dur.dh", jours, heures) }
        if heures > 0 { return L.s("dur.hm", heures, mins) }
        return L.s("dur.m", mins)
    }

    /// Une décimale : « 13,6% » en français, « 13.6% » en anglais.
    static func pourcent1(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: L.lang)
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v)) + "%"
    }

    private static func dateFormat(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang)
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    /// « samedi », « Saturday »
    static func jour(_ d: Date) -> String { dateFormat("EEEE").string(from: d) }
    /// « sam. 21 », « Sat 21 »
    static func jourCourt(_ d: Date) -> String { dateFormat("EEEd").string(from: d) }

    /// « 4h34 », « 17h » en français ; l'heure locale ailleurs (« 4:34 AM »).
    static func heure(_ d: Date) -> String {
        if L.isFrench {
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            let m = c.minute ?? 0
            return "\(c.hour ?? 0)h" + (m == 0 ? "" : String(format: "%02d", m))
        }
        return dateFormat("jmm").string(from: d)
    }

    /// « 1,08 Md », « 612 M », « 4 318 » ; « 1.08B » en anglais.
    static func grandNombre(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: L.isFrench ? "fr_FR" : L.lang)
        f.numberStyle = .decimal
        f.maximumFractionDigits = v >= 1e9 ? 2 : 0
        if v >= 1e9 { return (f.string(from: NSNumber(value: v / 1e9)) ?? "") + L.s("num.billion") }
        if v >= 1e6 { return (f.string(from: NSNumber(value: v / 1e6)) ?? "") + L.s("num.million") }
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }

    static func minutesSecondes(_ secondes: Double) -> String {
        let s = max(0, Int(secondes))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoSimple = ISO8601DateFormatter()

    static func date(_ s: String) -> Date? {
        iso.date(from: s) ?? isoSimple.date(from: s)
    }

    /// « claude-opus-5-5 » devient « Opus 5.5 »
    static func nomModele(_ id: String) -> String {
        var parts = id.replacingOccurrences(of: "claude-", with: "").split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return id }
        let famille = parts.removeFirst().capitalized
        let version = parts.filter { $0.count <= 2 && Int($0) != nil }.joined(separator: ".")
        return version.isEmpty ? famille : "\(famille) \(version)"
    }
}

/// `--demo` : données fictives pour les captures d'écran publiques (aucune donnée réelle lue).
enum Demo {
    static let on = CommandLine.arguments.contains("--demo")

    /// Pochette fictive dessinée à la volée.
    static func artwork() -> NSImage {
        NSImage(size: NSSize(width: 300, height: 300), flipped: false) { r in
            NSGradient(colors: [NSColor(red: 0.20, green: 0.10, blue: 0.45, alpha: 1),
                                NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)])?
                .draw(in: r, angle: 60)
            for (i, a) in [0.35, 0.22, 0.12].enumerated() {
                let d = CGFloat(220 - i * 60)
                NSColor(white: 1, alpha: a).setFill()
                NSBezierPath(ovalIn: NSRect(x: 150 - d / 2, y: 150 - d / 2, width: d, height: d)).fill()
            }
            return true
        }
    }
}
