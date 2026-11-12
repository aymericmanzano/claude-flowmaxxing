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

    /// Montant sans espace avant le symbole : « 229,84$ », « 3,20€ ».
    static func montant(_ v: Double, symbole: String) -> String {
        (decimal.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)) + symbole
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
        if jours > 0 { return "\(jours) j \(heures) h" }
        if heures > 0 { return "\(heures) h \(mins) min" }
        return "\(mins) min"
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
