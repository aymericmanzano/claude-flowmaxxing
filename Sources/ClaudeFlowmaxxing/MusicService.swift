import AppKit

/// Morceau en cours dans une app de musique, par AppleScript : Spotify, Musique d'Apple, VLC.
/// Une app n'est jamais lancée par Claude Flowmaxxing : on ne lui parle que si elle est déjà ouverte.
/// Si plusieurs jouent, on suit celle qui a commencé à jouer en dernier.
/// Pour les autres apps (Deezer, Tidal, navigateur…), les boutons envoient les touches multimédia.
final class MusicService: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var isPlaying = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var permissionDenied = false
    /// Nom de l'app suivie (« Spotify », « Musique », « VLC »).
    @Published private(set) var appName = ""

    struct Player {
        let id: String
        let name: String
    }

    static let players = [
        Player(id: "com.spotify.client", name: "Spotify"),
        Player(id: "com.apple.Music", name: "Musique"),
        Player(id: "org.videolan.vlc", name: "VLC"),
    ]

    private struct Snapshot {
        var playing: Bool
        var title: String
        var artist: String
        var position: Double
        var duration: Double
        /// Adresse de la pochette (Spotify) ou clé du morceau (Musique) pour savoir quand la recharger.
        var artworkKey: String?
    }

    private var current: Player?
    private var wasPlaying: [String: Bool] = [:]
    private var artworkKey: String?
    private var timer: Timer?

    init() {
        if Demo.on {
            running = true; isPlaying = true; appName = "Spotify"
            title = "Late Night Commit"; artist = "The Refactors"
            position = 74; duration = 212; artwork = Demo.artwork()
            return
        }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func isOpen(_ p: Player) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == p.id }
    }

    func poll() {
        if Demo.on { return }
        let open = Self.players.filter(isOpen)
        guard !open.isEmpty else {
            if running { reset() }
            current = nil
            return
        }
        var snaps: [String: Snapshot] = [:]
        var denied = false
        for p in open {
            switch read(p) {
            case .success(let s): snaps[p.id] = s
            case .failure(.denied): denied = true
            case .failure: break
            }
        }
        // Une app qui passe à la lecture devient l'app suivie.
        for p in open {
            let playing = snaps[p.id]?.playing ?? false
            if playing && wasPlaying[p.id] != true { current = p }
            wasPlaying[p.id] = playing
        }
        if let c = current, !open.contains(where: { $0.id == c.id }) { current = nil }
        if current == nil {
            current = open.first(where: { snaps[$0.id]?.playing == true })
                ?? open.first(where: { snaps[$0.id] != nil })
                ?? open.first
        }
        guard let p = current else { return }
        running = true
        if appName != p.name { appName = p.name }
        guard let s = snaps[p.id] else {
            permissionDenied = denied
            isPlaying = false
            return
        }
        permissionDenied = false
        isPlaying = s.playing
        if title != s.title { title = s.title }
        if artist != s.artist { artist = s.artist }
        position = s.position
        duration = s.duration
        let key = s.artworkKey.map { "\(p.id)|\($0)" }
        if key != artworkKey {
            artworkKey = key
            loadArtwork(p, s.artworkKey, key)
        }
    }

    private enum ReadError: Error { case denied, empty }

    private func read(_ p: Player) -> Result<Snapshot, ReadError> {
        let sep = "\u{1F}"
        let source: String
        switch p.id {
        case "com.spotify.client":
            source = """
            tell application id "com.spotify.client"
                set s to player state as string
                if s is "stopped" then return "stopped"
                set t to current track
                return s & "\(sep)" & (name of t) & "\(sep)" & (artist of t) & "\(sep)" & (player position as string) & "\(sep)" & (((duration of t) / 1000) as string) & "\(sep)" & (artwork url of t)
            end tell
            """
        case "com.apple.Music":
            source = """
            tell application id "com.apple.Music"
                set s to player state as string
                if s is "stopped" then return "stopped"
                set t to current track
                return s & "\(sep)" & (name of t) & "\(sep)" & (artist of t) & "\(sep)" & (player position as string) & "\(sep)" & (duration of t as string) & "\(sep)" & (persistent ID of t)
            end tell
            """
        default: // VLC
            source = """
            tell application id "org.videolan.vlc"
                try
                    if name of current item is missing value then return "stopped"
                on error
                    return "stopped"
                end try
                if playing then
                    set s to "playing"
                else
                    set s to "paused"
                end if
                return s & "\(sep)" & (name of current item) & "\(sep)" & "" & "\(sep)" & (current time as string) & "\(sep)" & (duration of current item as string) & "\(sep)" & ""
            end tell
            """
        }
        var err: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&err).stringValue else {
            if let code = err?[NSAppleScript.errorNumber] as? Int, code == -1743 { return .failure(.denied) }
            return .failure(.empty)
        }
        if result == "stopped" {
            return .success(Snapshot(playing: false, title: "", artist: "", position: 0, duration: 0, artworkKey: nil))
        }
        let parts = result.components(separatedBy: sep)
        guard parts.count >= 6 else { return .failure(.empty) }
        func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return .success(Snapshot(playing: parts[0] == "playing", title: parts[1], artist: parts[2],
                                 position: num(parts[3]), duration: num(parts[4]),
                                 artworkKey: parts[5].isEmpty ? nil : parts[5]))
    }

    private func loadArtwork(_ p: Player, _ value: String?, _ key: String?) {
        guard let value else { artwork = nil; return }
        if p.id == "com.spotify.client" {
            guard let url = URL(string: value) else { artwork = nil; return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                let img = data.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async { if self?.artworkKey == key { self?.artwork = img } }
            }.resume()
        } else if p.id == "com.apple.Music" {
            // Pochette lue directement dans Musique : données brutes de la première illustration.
            DispatchQueue.global(qos: .utility).async { [weak self] in
                var err: NSDictionary?
                let script = "tell application id \"com.apple.Music\" to get raw data of artwork 1 of current track"
                let data = NSAppleScript(source: script)?.executeAndReturnError(&err).data
                let img = data.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async { if self?.artworkKey == key { self?.artwork = img } }
            }
        } else {
            artwork = nil
        }
    }

    private func reset() {
        running = false
        isPlaying = false
        title = ""
        artist = ""
        appName = ""
        artwork = nil
        artworkKey = nil
        permissionDenied = false
    }

    private func send(_ verb: String) {
        guard let p = current, isOpen(p) else {
            MediaKeys.send(verb)
            return
        }
        let command: String
        switch (p.id, verb) {
        case ("org.videolan.vlc", "playpause"): command = "play"
        case ("org.videolan.vlc", let v): command = v
        case (_, "playpause"): command = "playpause"
        case (_, let v): command = v + " track"
        }
        var err: NSDictionary?
        NSAppleScript(source: "tell application id \"\(p.id)\" to \(command)")?.executeAndReturnError(&err)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.poll() }
    }

    func playPause() { send("playpause") }
    func next() { send("next") }
    func previous() { send("previous") }
}

/// Touches multimédia du clavier (lecture, suivant, précédent), reçues par l'app de musique
/// active quelle qu'elle soit. macOS demande l'autorisation « Accessibilité » au premier envoi.
enum MediaKeys {
    static func send(_ verb: String) {
        let key: Int32
        switch verb {
        case "next": key = 17       // NX_KEYTYPE_NEXT
        case "previous": key = 18   // NX_KEYTYPE_PREVIOUS
        default: key = 16           // NX_KEYTYPE_PLAY
        }
        guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) else { return }
        for down in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((key << 16) | ((down ? 0xA : 0xB) << 8))
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags,
                                           timestamp: 0, windowNumber: 0, context: nil,
                                           subtype: 8, data1: data1, data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
