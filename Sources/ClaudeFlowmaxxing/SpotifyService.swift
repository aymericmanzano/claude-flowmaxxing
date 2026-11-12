import AppKit

/// Morceau en cours dans Spotify, par AppleScript. Spotify n'est jamais lancé par ClaudeFlowmaxxing :
/// on ne lui parle que s'il est déjà ouvert.
final class SpotifyService: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var isPlaying = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var permissionDenied = false

    private var artworkURL: String?
    private var timer: Timer?
    static let bundleID = "com.spotify.client"

    init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private var spotifyIsOpen: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleID }
    }

    func poll() {
        guard spotifyIsOpen else {
            if running { reset() }
            return
        }
        running = true
        let source = """
        tell application id "com.spotify.client"
            set s to player state as string
            if s is "stopped" then return "stopped"
            set t to current track
            return s & "\u{1F}" & (name of t) & "\u{1F}" & (artist of t) & "\u{1F}" & (artwork url of t) & "\u{1F}" & (player position as string) & "\u{1F}" & ((duration of t) as string)
        end tell
        """
        var err: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&err).stringValue else {
            if let code = err?[NSAppleScript.errorNumber] as? Int, code == -1743 { permissionDenied = true }
            return
        }
        permissionDenied = false
        if result == "stopped" {
            isPlaying = false
            return
        }
        let parts = result.components(separatedBy: "\u{1F}")
        guard parts.count >= 6 else { return }
        isPlaying = parts[0] == "playing"
        if title != parts[1] { title = parts[1] }
        if artist != parts[2] { artist = parts[2] }
        position = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        duration = (Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0) / 1000
        if parts[3] != artworkURL {
            artworkURL = parts[3]
            loadArtwork(parts[3])
        }
    }

    private func loadArtwork(_ s: String) {
        guard let url = URL(string: s) else { artwork = nil; return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let img = data.flatMap { NSImage(data: $0) }
            DispatchQueue.main.async {
                if self?.artworkURL == s { self?.artwork = img }
            }
        }.resume()
    }

    private func reset() {
        running = false
        isPlaying = false
        title = ""
        artist = ""
        artwork = nil
        artworkURL = nil
    }

    func send(_ command: String) {
        guard spotifyIsOpen else { return }
        var err: NSDictionary?
        NSAppleScript(source: "tell application id \"com.spotify.client\" to \(command)")?.executeAndReturnError(&err)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.poll() }
    }

    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }
}
