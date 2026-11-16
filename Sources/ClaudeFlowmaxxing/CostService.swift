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

    /// Onglet Tableau : chiffres depuis le début de la fenêtre de la semaine.
    struct WeekStats: Equatable {
        var tokens: Double = 0
        var calls = 0
        var cost: Double = 0
        var topFamily: String?
        var topFamilyShare: Double = 0
        /// Dossiers de travail regroupés, part du coût en pourcentage, du plus gros au plus petit.
        var groups: [(name: String, share: Double)] = []
        static func == (a: WeekStats, b: WeekStats) -> Bool {
            a.tokens == b.tokens && a.calls == b.calls && a.cost == b.cost && a.groups.map(\.name) == b.groups.map(\.name)
        }
    }
    @Published private(set) var weekStats = WeekStats()
    /// Coût par tranche de 15 minutes sur 8 jours, pour la forme des courbes avant le premier relevé.
    @Published private(set) var buckets: [(Date, Double)] = []

    /// Début de la fenêtre de la semaine, donné par les quotas.
    var windowStart: Date? {
        didSet {
            if Demo.on { return }
            let v = windowStart
            queue.async { [weak self] in self?.windowStartQ = v; self?.publish() }
        }
    }
    private var windowStartQ: Date?

    private struct Entry { let date: Date; let model: String; let cost: Double; let tokens: Double; let cwd: String }

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
            weekStats = WeekStats(tokens: 1_080_000_000, calls: 4318, cost: 1412, topFamily: "Opus", topFamilyShare: 91,
                                  groups: [("Website", 48), ("Client work", 19), ("Newsletter", 12),
                                           ("Side project", 9), ("Teaching", 7), (L.s("board.others"), 5)])
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
            func n(_ k: String) -> Double { (usage[k] as? NSNumber)?.doubleValue ?? 0 }
            let tokens = n("input_tokens") + n("output_tokens") + n("cache_read_input_tokens") + n("cache_creation_input_tokens")
            entries.append(Entry(date: ts, model: model, cost: cost, tokens: tokens, cwd: (obj["cwd"] as? String) ?? ""))
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

        // Tranches de 15 minutes.
        var byBucket: [Date: Double] = [:]
        for e in entries {
            let t = (e.date.timeIntervalSince1970 / 900).rounded(.down) * 900
            byBucket[Date(timeIntervalSince1970: t), default: 0] += e.cost
        }
        let bucketList = byBucket.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        // Semaine de quota : depuis le début de la fenêtre, sinon les 7 derniers jours.
        let since = windowStartQ ?? now.addingTimeInterval(-7 * 86400)
        let win = entries.filter { $0.date >= since }
        var stats = WeekStats()
        stats.tokens = win.reduce(0) { $0 + $1.tokens }
        stats.calls = win.count
        stats.cost = win.reduce(0) { $0 + $1.cost }
        var byFamily: [String: Int] = [:]
        for e in win { byFamily[Format.nomModele(e.model).split(separator: " ").first.map(String.init) ?? e.model, default: 0] += 1 }
        if let f = byFamily.max(by: { $0.value < $1.value }), stats.calls > 0 {
            stats.topFamily = f.key
            stats.topFamilyShare = Double(f.value) / Double(stats.calls) * 100
        }
        stats.groups = Self.groups(win.map { ($0.cwd, $0.cost) })

        DispatchQueue.main.async {
            self.weekStats = stats
            self.buckets = bucketList
            self.ready = true
            self.today = todayCost
            self.projection = proj
            self.week = weekCost
            self.topModel = top?.key
            self.topShare = (top != nil && weekCost > 0) ? top!.value / weekCost * 100 : 0
        }
    }

    /// Regroupe les dossiers de travail : on cherche le dossier le plus profond qui contient
    /// au moins 70% de la dépense, puis on compte par sous-dossier de premier niveau.
    /// Cinq groupes au plus, le reste dans « Autres ».
    static func groups(_ items: [(String, Double)]) -> [(name: String, share: Double)] {
        let total = items.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }
        let paths = items.map { ($0.0.split(separator: "/").map(String.init), $0.1) }
        var root: [String] = []
        while true {
            var next: [String: Double] = [:]
            for (p, c) in paths where p.count > root.count && Array(p.prefix(root.count)) == root {
                next[p[root.count], default: 0] += c
            }
            guard let best = next.max(by: { $0.value < $1.value }), best.value / total >= 0.7 else { break }
            root.append(best.key)
        }
        var byGroup: [String: Double] = [:]
        for (p, c) in paths {
            let name: String
            if p.count > root.count, Array(p.prefix(root.count)) == root { name = p[root.count] }
            else if p == root { name = L.s("board.root") }
            else { name = L.s("board.others") }
            byGroup[name, default: 0] += c
        }
        let sorted = byGroup.filter { $0.key != L.s("board.others") }.sorted { $0.value > $1.value }
        var out = sorted.prefix(5).map { (name: $0.key, share: $0.value / total * 100) }
        let rest = total - sorted.prefix(5).reduce(0) { $0 + $1.value }
        if rest / total * 100 >= 0.5 { out.append((name: L.s("board.others"), share: rest / total * 100)) }
        return out
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
