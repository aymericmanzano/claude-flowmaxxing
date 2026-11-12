import Foundation

/// Détecte les sessions Claude Code ouvertes et celles qui génèrent une réponse.
/// Source : ~/.claude/sessions/<pid>.json, que Claude Code tient à jour pour chaque session
/// (CLI ou app de bureau) avec un statut « busy » ou « idle ».
final class ClaudeMonitor: ObservableObject {
    @Published private(set) var visible = false
    @Published private(set) var generating = false
    @Published private(set) var busyNames: [String] = []
    @Published private(set) var openCount = 0
    /// Dernière session passée d'« occupée » à « au repos » : une réponse vient de finir.
    @Published private(set) var lastFinished: FinishEvent?

    struct FinishEvent: Equatable {
        let id = UUID()
        let name: String
        /// Identifiant de la session dans l'app de bureau (« local_… »), absent pour le terminal.
        let hostSessionId: String?
    }

    private var lastStatus: [Int32: String] = [:]
    private var primed = false

    private let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/sessions")
    private let queue = DispatchQueue(label: "claudeflowmaxxing.claude", qos: .utility)
    private var timer: Timer?

    init() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        queue.async { [weak self] in
            guard let self else { return }
            var open = 0
            var busy: [String] = []
            var statuses: [Int32: String] = [:]
            var finished: [FinishEvent] = []
            let files = (try? FileManager.default.contentsOfDirectory(
                at: self.sessionsDir, includingPropertiesForKeys: nil)) ?? []
            for f in files where f.pathExtension == "json" {
                guard let data = try? Data(contentsOf: f),
                      let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let pid = (d["pid"] as? NSNumber)?.int32Value,
                      kill(pid, 0) == 0 else { continue }
                open += 1
                let status = (d["status"] as? String) ?? ""
                statuses[pid] = status
                if self.primed, self.lastStatus[pid] == "busy", status != "busy" {
                    finished.append(FinishEvent(name: (d["name"] as? String) ?? "Claude",
                                                hostSessionId: d["hostSessionId"] as? String))
                }
                if status == "busy" {
                    busy.append((d["name"] as? String) ?? "Session sans nom")
                }
            }
            busy.sort()
            self.lastStatus = statuses
            self.primed = true
            let vis = open > 0
            let gen = !busy.isEmpty
            DispatchQueue.main.async {
                if self.visible != vis { self.visible = vis }
                if self.generating != gen { self.generating = gen }
                if self.busyNames != busy { self.busyNames = busy }
                if self.openCount != open { self.openCount = open }
                if let event = finished.last { self.lastFinished = event }
            }
        }
    }
}
