import Foundation

/// Accès au jeton OAuth de Claude Code rangé dans le trousseau, et renouvellement.
/// Tout passe par l'outil `security`, déjà autorisé sur cet élément par Claude Code.
/// Le secret n'est jamais écrit sur le disque. L'écriture passe en hexadécimal par l'entrée
/// standard de `security -i` quand c'est possible ; au-delà d'environ 3,5 Ko (cas courant),
/// elle passe en argument de `security add-generic-password`, comme le fait Claude Code,
/// et reste alors visible un instant dans la liste des processus de l'utilisateur.
enum TokenStore {
    static let service = "Claude Code-credentials"
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    // Vérifié dans le binaire de Claude Code 2.1.322.
    static let endpoints = ["https://platform.claude.com/v1/oauth/token"]

    /// Jeton obtenu mais pas encore enregistré dans le trousseau : on le garde en mémoire
    /// et on retente l'écriture au prochain passage.
    private static var pending: [String: Any]?

    struct Credentials {
        var root: [String: Any]
        var oauth: [String: Any]
        var accessToken: String { oauth["accessToken"] as? String ?? "" }
        var refreshToken: String? { oauth["refreshToken"] as? String }
        var expiresAt: Date? {
            (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        }
        /// Expiré, ou expire dans les deux prochaines minutes.
        var isExpired: Bool { (expiresAt ?? .distantFuture) < Date().addingTimeInterval(120) }
    }

    enum RenewError: Error {
        case noRefreshToken, rejected(Int), network, writeFailed
    }

    // MARK: Lecture

    static func read() -> Credentials? {
        guard let out = run(["find-generic-password", "-s", service, "-w"]), out.status == 0,
              let json = try? JSONSerialization.jsonObject(with: out.data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              oauth["accessToken"] is String else { return nil }
        return Credentials(root: json, oauth: oauth)
    }

    /// Nom de compte de l'élément du trousseau (attribut « acct »).
    private static func account() -> String? {
        guard let out = run(["find-generic-password", "-s", service]), out.status == 0,
              let text = String(data: out.data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") where line.contains("\"acct\"") {
            if let eq = line.range(of: "=\"") {
                return String(line[eq.upperBound...].dropLast())
            }
        }
        return nil
    }

    // MARK: Renouvellement

    private static var lastAttempt: Date?
    private static let lock = NSLock()

    /// Renouvelle le jeton et réécrit l'élément du trousseau. Au plus une tentative
    /// toutes les 5 minutes. Renvoie le nouveau jeton d'accès.
    static func renew(_ creds: Credentials) -> Result<String, RenewError> {
        lock.lock(); defer { lock.unlock() }
        if pending == nil, let last = lastAttempt, Date().timeIntervalSince(last) < 300 { return .failure(.rejected(0)) }
        lastAttempt = Date()

        // Claude Code a peut-être renouvelé entre-temps : on relit avant d'agir.
        if let fresh = read(), !fresh.isExpired { pending = nil; return .success(fresh.accessToken) }
        if let p = pending, let oauth = p["claudeAiOauth"] as? [String: Any], let access = oauth["accessToken"] as? String {
            if write(p), read()?.accessToken == access { pending = nil; Log.write("renouvellement : écriture rattrapée") }
            return .success(access)
        }
        guard let refresh = creds.refreshToken else { return .failure(.noRefreshToken) }

        var lastError: RenewError = .network
        for endpoint in endpoints {
            switch post(endpoint, refresh: refresh) {
            case .success(let body):
                guard let access = body["access_token"] as? String else { return .failure(.rejected(200)) }
                var oauth = creds.oauth
                oauth["accessToken"] = access
                if let r = body["refresh_token"] as? String { oauth["refreshToken"] = r }
                if let exp = (body["expires_in"] as? NSNumber)?.doubleValue {
                    oauth["expiresAt"] = Int64((Date().timeIntervalSince1970 + exp) * 1000)
                }
                if let scope = body["scope"] as? String {
                    oauth["scopes"] = scope.split(separator: " ").map(String.init)
                }
                var root = creds.root
                root["claudeAiOauth"] = oauth
                guard write(root), read()?.accessToken == access else {
                    Log.write("renouvellement : jeton obtenu mais écriture dans le trousseau en échec (longueur \(lastCommandLength))")
                    pending = root
                    return .success(access)
                }
                Log.write("renouvellement : jeton renouvelé")
                return .success(access)
            case .failure(let e):
                lastError = e
                // Un refus explicite (400/401) ne se retente pas ailleurs : le jeton est peut-être consommé.
                if case .rejected(let code) = e, code == 400 || code == 401 { return .failure(e) }
            }
        }
        return .failure(lastError)
    }

    private static func post(_ endpoint: String, refresh: String) -> Result<[String: Any], RenewError> {
        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": clientID,
        ])
        let sem = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], RenewError> = .failure(.network)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { sem.signal() }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if err != nil { return }
            if code == 200, let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                result = .success(json)
            } else {
                Log.write("renouvellement : HTTP \(code) sur \(endpoint)")
                result = .failure(.rejected(code))
            }
        }.resume()
        sem.wait()
        return result
    }

    // MARK: Écriture

    @discardableResult
    static func write(_ root: [String: Any], to target: String = service, account given: String? = nil) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: root),
              let acct = given ?? account() ?? Optional(NSUserName()),
              !acct.contains("\"") else { return false }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        // `security -i` lit la commande sur l'entrée standard : le secret n'apparaît pas dans `ps`.
        let command = "add-generic-password -U -a \"\(acct)\" -s \"\(target)\" -X \(hex)\n"
        lastCommandLength = command.utf8.count
        if command.utf8.count < 3500, let out = run(["-i"], stdin: Data(command.utf8)), out.status == 0 {
            return true
        }
        // Trop long pour `security -i` (les identifiants de Claude Code dépassent 30 Ko) :
        // passage en argument, comme le fait Claude Code lui-même. Visible dans `ps` le temps de l'appel.
        guard let out = run(["add-generic-password", "-U", "-a", acct, "-s", target, "-X", hex]) else { return false }
        return out.status == 0
    }
    static var lastCommandLength = 0

    static func readRaw(_ target: String) -> [String: Any]? {
        guard let out = run(["find-generic-password", "-s", target, "-w"]), out.status == 0 else { return nil }
        return try? JSONSerialization.jsonObject(with: out.data) as? [String: Any]
    }

    static func delete(_ target: String) {
        _ = run(["delete-generic-password", "-s", target])
    }

    /// Essai sans risque : copie l'élément réel dans un élément jetable, relit, compare, supprime.
    static func selfTest() {
        guard let root = readRaw(service) else { Log.write("essai : lecture impossible"); return }
        let scratch = "ClaudeFlowmaxxing-essai"
        delete(scratch)
        let ok = write(root, to: scratch, account: "claudeflowmaxxing")
        let back = readRaw(scratch)
        let same = back.map { NSDictionary(dictionary: $0).isEqual(to: root) } ?? false
        delete(scratch)
        Log.write("essai : longueur \(lastCommandLength), écriture \(ok), relu identique \(same)")
    }

    /// Réécrit l'élément réel à l'identique, puis compare le tout.
    static func identityTest() {
        guard let root = readRaw(service) else { Log.write("identité : lecture impossible"); return }
        let acct = account()
        let ok = write(root)
        let same = readRaw(service).map { NSDictionary(dictionary: $0).isEqual(to: root) } ?? false
        Log.write("identité : compte trouvé \(acct != nil), écriture \(ok), relu identique \(same)")
    }

    // MARK: Outil security

    private static func run(_ args: [String], stdin: Data? = nil) -> (status: Int32, data: Data)? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = args
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = FileHandle.nullDevice
        let inPipe = Pipe()
        p.standardInput = stdin == nil ? FileHandle.nullDevice : inPipe
        do { try p.run() } catch { return nil }
        if let stdin {
            inPipe.fileHandleForWriting.write(stdin)
            try? inPipe.fileHandleForWriting.close()
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, data)
    }
}
