import Foundation

struct Quota: Identifiable, Equatable {
    let id: String
    let label: String
    let percent: Double
    let resetsAt: Date?
}

struct Credits: Equatable {
    let used: Double
    let limit: Double?
    let percent: Double?
    let symbole: String
    var capReached = false
}

/// Quotas d'abonnement lus sur le point d'accès d'utilisation d'Anthropic, avec le jeton
/// que Claude Code range dans le trousseau. Le jeton reste en mémoire, jamais écrit.
final class UsageService: ObservableObject {
    @Published private(set) var fiveHour: Quota?
    @Published private(set) var sevenDay: Quota?
    @Published private(set) var others: [Quota] = []
    @Published private(set) var credits: Credits?
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?

    private var timer: Timer?
    private var inFlight = false

    init() {
        if Demo.on {
            let now = Date()
            fiveHour = Quota(id: "five_hour", label: L.s("quota.5h"), percent: 42, resetsAt: now.addingTimeInterval(2 * 3600 + 13 * 60))
            sevenDay = Quota(id: "seven_day", label: L.s("quota.7d"), percent: 61, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600))
            others = [Quota(id: "scoped-0", label: "Fable", percent: 18, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600))]
            credits = Credits(used: 12.40, limit: 50, percent: 24.8, symbole: "$")
            updated = now
            return
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func quota(slot: Int) -> Quota? {
        switch slot {
        case 1: return sevenDay
        case 2: return others.first ?? fiveHour
        default: return fiveHour
        }
    }

    func shortLabel(slot: Int) -> String {
        switch slot {
        case 1: return L.s("quota.7d.short")
        case 2: return others.first?.label ?? L.s("quota.5h.short")
        default: return L.s("quota.5h.short")
        }
    }

    func refreshIfStale() {
        if let u = updated, Date().timeIntervalSince(u) < 30 { return }
        refresh()
    }

    static let testMode = CommandLine.arguments.contains { $0 == "--essai-trousseau" || $0 == "--reecrire-identique" }
    private var loggedKeys = false

    private var retryAfter: Date?

    func refresh() {
        if Demo.on { return }
        guard !inFlight, !Self.testMode else { return }
        if let r = retryAfter, r > Date() { return }
        inFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let creds = TokenStore.read() else {
                self.finish(error: L.s("err.noToken"))
                return
            }
            var token = creds.accessToken
            if creds.isExpired {
                switch TokenStore.renew(creds) {
                case .success(let t):
                    token = t
                case .failure(.writeFailed):
                    self.finish(error: L.s("err.notSaved"))
                    return
                case .failure(.rejected(let code)) where code == 400 || code == 401:
                    self.finish(error: L.s("err.refused"))
                    return
                case .failure:
                    self.finish(error: L.s("err.renewLater"))
                    return
                }
            }
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 15
            URLSession.shared.dataTask(with: req) { data, resp, err in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if err != nil {
                    self.finish(error: L.s("err.offline"))
                } else if code == 401 || code == 403 {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) }?.prefix(300) ?? ""
                    Log.write("quotas HTTP \(code) : \(body)")
                    self.finish(error: L.s("err.denied"))
                } else if code == 429 {
                    let wait = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "retry-after").flatMap(Double.init).map { max($0, 60) } ?? 60
                    Log.write("quotas : HTTP 429, nouvel essai dans \(Int(wait)) s")
                    self.retryAfter = Date().addingTimeInterval(wait)
                    // On garde les dernières valeurs ; message seulement si on n'en a aucune.
                    self.finish(error: self.updated == nil ? L.s("err.rate", Int(max(wait, 60) / 60)) : nil)
                } else if code != 200 {
                    self.finish(error: L.s("err.unexpected", code))
                } else if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.apply(json)
                } else {
                    self.finish(error: L.s("err.unreadable"))
                }
            }.resume()
        }
    }

    private func finish(error: String?) {
        if let error { Log.write("quotas : \(error)") }
        DispatchQueue.main.async {
            self.inFlight = false
            self.error = error
        }
    }

    private func apply(_ json: [String: Any]) {
        if !loggedKeys {
            loggedKeys = true
            let shape = json.keys.sorted().map { k -> String in
                if let d = json[k] as? [String: Any] { return "\(k){\(d.keys.sorted().joined(separator: ","))}" }
                return json[k] is NSNull ? "\(k)=null" : k
            }
            Log.write("quotas : forme de la réponse \(shape.joined(separator: " "))")
        }
        func quota(_ key: String, _ label: String) -> Quota? {
            guard let d = json[key] as? [String: Any], let u = Self.number(d["utilization"]) else { return nil }
            return Quota(id: key, label: label, percent: u, resetsAt: (d["resets_at"] as? String).flatMap(Format.date))
        }
        let five = quota("five_hour", L.s("quota.5h"))
        let seven = quota("seven_day", L.s("quota.7d"))
        // Quotas par modèle (Fable…) : tableau « limits », entrées « weekly_scoped ».
        var extras: [Quota] = []
        for (i, l) in ((json["limits"] as? [[String: Any]]) ?? []).enumerated() where (l["kind"] as? String) == "weekly_scoped" {
            let scope = l["scope"] as? [String: Any]
            let model = scope?["model"] as? [String: Any]
            let label = (model?["display_name"] as? String) ?? "Quota \(i)"
            guard let p = Self.number(l["percent"]) else { continue }
            extras.append(Quota(id: "scoped-\(i)", label: label, percent: p,
                                resetsAt: (l["resets_at"] as? String).flatMap(Format.date)))
        }
        // Crédits : montants en unités mineures (decimal_places), affichés même plafond atteint.
        var cr: Credits?
        if let e = json["extra_usage"] as? [String: Any],
           (e["is_enabled"] as? Bool) == true || (e["credits_ever_enabled"] as? Bool) == true {
            let currency = (e["currency"] as? String)?.uppercased()
            let symbole = currency == "USD" ? "$" : (currency == "GBP" ? "£" : "€")
            let div = pow(10, Self.number(e["decimal_places"]) ?? 2)
            cr = Credits(used: (Self.number(e["used_credits"]) ?? 0) / div,
                         limit: Self.number(e["monthly_limit"]).map { $0 / div },
                         percent: Self.number(e["utilization"]),
                         symbole: symbole,
                         capReached: (e["spend_limit_reached"] as? Bool) == true)
        }
        DispatchQueue.main.async {
            self.inFlight = false
            self.fiveHour = five
            self.sevenDay = seven
            self.others = extras
            self.credits = cr
            self.error = nil
            self.updated = Date()
        }
    }

    private static func number(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        return nil
    }
}
