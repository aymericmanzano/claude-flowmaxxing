import QuartzCore
import AppKit
import Combine
import SwiftUI

enum NotchMode: Equatable { case hidden, compact, toast, expanded }

/// État partagé par toutes les vues.
final class AppState: ObservableObject {
    @Published var mode: NotchMode = .hidden
    @Published var shapeSize: CGSize = .zero
    @Published var expanded = false
    @Published var page = 0
    /// Décalage en cours pendant un balayage à deux doigts.
    @Published var pageDrag: CGFloat = 0
    /// Quota affiché dans l'encoche : 0 = 5 heures, 1 = 7 jours, 2 = quota du modèle (Fable).
    @Published var notchSlot: Int {
        didSet { UserDefaults.standard.set(notchSlot, forKey: "quotaEncoche") }
    }
    /// Nom de la session qui vient de finir, affiché quelques secondes sous l'encoche.
    @Published var toast: String?
    @Published var toastSession: String?

    /// Ouvre la session dans l'app Claude ; sans identifiant (session du terminal), ouvre le panneau.
    func openToastSession() {
        if let id = toastSession,
           let url = URL(string: "claude://code/continue?session=\(id)") {
            NSWorkspace.shared.open(url)
            toast = nil
        } else {
            toast = nil
            page = 0
            expanded = true
        }
    }
    @Published var notchWidth: CGFloat = 180
    /// Encoche fermée : tout s'affiche à droite de l'encoche physique, pour ne jamais
    /// recouvrir les menus de l'app au premier plan, à gauche. `shapeOffset` décale le centre
    /// de la forme par rapport à l'encoche ; `contentShift` compense la position de la fenêtre.
    @Published var rightEar: CGFloat = 0
    @Published var leftEar: CGFloat = 0
    @Published var shapeOffset: CGFloat = 0
    @Published var contentShift: CGFloat = 0
    @Published var notchHeight: CGFloat = 32

    init() { notchSlot = UserDefaults.standard.integer(forKey: "quotaEncoche") }

    /// Passe au quota suivant, en sautant ceux qui n'existent pas.
    func cycleSlot(_ usage: UsageService) {
        let count = usage.others.isEmpty ? 2 : 3
        notchSlot = (notchSlot + 1) % count
    }

    func openMusic() {
        page = 1
        expanded = true
    }
}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Le premier clic agit tout de suite, même si la fenêtre n'est pas active.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let claude = ClaudeMonitor()
    let usage = UsageService()
    let cost = CostService()
    let music = MusicService()

    private var panel: NotchPanel!
    private var bag = Set<AnyCancellable>()
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var swipeActive = false
    private var screen: NSScreen?

    static let flare: CGFloat = 6      // évasement en haut des bords
    static let expandedSize = CGSize(width: 580, height: 268)
    static let toastHeight: CGFloat = 34

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false

        let root = RootView(state: state, claude: claude, usage: usage, cost: cost, music: music)
        let host = FirstClickHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host

        measureNotch()

        Publishers.CombineLatest4(claude.$visible, music.$isPlaying, state.$expanded, claude.$generating)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.update() } }
            .store(in: &bag)

        claude.$lastFinished
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.showToast(event.name, session: event.hostSessionId) }
            .store(in: &bag)
        state.$toast
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.update() } }
            .store(in: &bag)

        state.$expanded
            .removeDuplicates()
            .sink { [weak self] open in
                guard let self, open else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.usage.refreshIfStale()
                    self.cost.refresh()
                }
                self.state.page = (!self.claude.visible && self.music.running) ? 1 : self.state.page
            }
            .store(in: &bag)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.state.expanded == true { self?.state.expanded = false }
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            guard let self, self.state.expanded else { return e }
            return self.handleSwipe(e) ? nil : e
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53, self?.state.expanded == true { self?.state.expanded = false; return nil }
            return e
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.measureNotch()
            self?.update(force: true)
        }
        update(force: true)

        // Pour les essais : `--ouvert` ouvre le panneau, `--musique` sur la page Musique.
        let args = CommandLine.arguments
        if args.contains("--essai-trousseau") { DispatchQueue.global().async { TokenStore.selfTest() } }
        if args.contains("--reecrire-identique") { DispatchQueue.global().async { TokenStore.identityTest() } }
        if args.contains("--essai-fin") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showToast("Refactor auth flow") }
        }
        if args.contains("--ouvert") || args.contains("--musique") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.state.page = args.contains("--musique") ? 1 : 0
                self.state.expanded = true
            }
        }
    }

    /// Balayage horizontal à deux doigts sur le pavé tactile : la page suit les doigts,
    /// puis bascule au-delà d'un tiers de course, sinon revient en place.
    private func handleSwipe(_ e: NSEvent) -> Bool {
        guard e.hasPreciseScrollingDeltas else { return false }
        if !e.momentumPhase.isEmpty { return swipeActive } // on ignore l'inertie
        let dx = e.scrollingDeltaX * (e.isDirectionInvertedFromDevice ? 1 : -1)
        switch e.phase {
        case .began:
            swipeActive = false
            return false
        case .changed:
            if !swipeActive {
                guard abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) else { return false }
                swipeActive = true
            }
            var drag = state.pageDrag + dx
            // Résistance au bord : pas de page avant la première ni après la dernière.
            if (state.page == 0 && drag > 0) || (state.page == 1 && drag < 0) { drag = state.pageDrag + dx * 0.25 }
            state.pageDrag = max(-300, min(300, drag))
            return true
        case .ended, .cancelled:
            guard swipeActive else { return false }
            swipeActive = false
            let threshold: CGFloat = 70
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                if state.pageDrag < -threshold { state.page = 1 }
                else if state.pageDrag > threshold { state.page = 0 }
                state.pageDrag = 0
            }
            return true
        default:
            return swipeActive
        }
    }

    static let toastDuration: TimeInterval = 6
    private var toastToken = 0

    private func showToast(_ name: String, session: String? = nil) {
        toastToken += 1
        let token = toastToken
        state.toastSession = session
        state.toast = name
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.toastDuration) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.state.toast = nil
        }
    }

    private func measureNotch() {
        let s = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        screen = s
        if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            state.notchWidth = s.frame.width - l.width - r.width
            state.notchHeight = s.safeAreaInsets.top
        } else {
            state.notchWidth = 180
            state.notchHeight = 30
        }
    }

    private var earWidth: CGFloat {
        claude.visible && music.isPlaying ? 118 : 90
    }

    /// Largeur à droite de l'encoche quand elle est fermée.
    private var rightEarWidth: CGFloat {
        claude.visible ? 82 : 44
    }

    /// Oreilles symétriques et étroites : assez pour le personnage et la pochette à gauche,
    /// le pourcentage et le rond à droite, sans recouvrir les menus de l'app au premier plan.
    private var leftEarWidth: CGFloat { rightEarWidth }

    /// Décalage du centre de la forme par rapport au centre de l'encoche.
    private func offset(for mode: NotchMode) -> CGFloat {
        mode == .compact ? (rightEarWidth - leftEarWidth) / 2 : 0
    }

    private func size(for mode: NotchMode) -> CGSize {
        let f = Self.flare
        switch mode {
        case .hidden:
            return CGSize(width: state.notchWidth + 2 * f, height: state.notchHeight)
        case .compact:
            return CGSize(width: state.notchWidth + leftEarWidth + rightEarWidth + 2 * f, height: state.notchHeight)
        case .toast:
            return CGSize(width: max(340, state.notchWidth + 2 * earWidth + 2 * f),
                          height: state.notchHeight + Self.toastHeight)
        case .expanded:
            return CGSize(width: max(Self.expandedSize.width, state.notchWidth + 2 * earWidth + 2 * f),
                          height: Self.expandedSize.height)
        }
    }

    private func currentMode() -> NotchMode {
        if state.expanded { return .expanded }
        if state.toast != nil { return .toast }
        if claude.visible || music.isPlaying { return .compact }
        return .hidden
    }

    /// Taille de la fenêtre : celle de la forme, sauf pendant une animation où elle prend
    /// la plus grande des deux. Le contenu du panneau a une taille fixe, donc agrandir la
    /// fenêtre ne provoque aucun recalcul visible. La fenêtre épouse la forme : chaque clic
    /// sur l'encoche lui arrive, sans minuteur ni zone transparente.
    private func frame(for mode: NotchMode) -> NSRect {
        guard let s = screen else { return .zero }
        let size = size(for: mode)
        return NSRect(x: s.frame.midX + offset(for: mode) - size.width / 2,
                      y: s.frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func placeWindow(_ frame: NSRect) {
        guard let s = screen else { return }
        guard panel.frame != frame else { return }
        // Redimensionner puis recalculer la vue dans la même image, sans animation implicite :
        // sinon SwiftUI dessine une image avec l'ancienne mise en page et l'encoche saute.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        state.contentShift = s.frame.midX - frame.midX
        panel.setFrame(frame, display: false)
        panel.contentView?.needsLayout = true
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        CATransaction.commit()
    }

    private var generation = 0

    private func update(force: Bool = false) {
        let mode = currentMode()
        let target = size(for: mode)
        let targetFrame = frame(for: mode)
        let ear = rightEarWidth
        if !force && mode == state.mode && target == state.shapeSize && ear == state.rightEar { return }
        generation += 1
        let gen = generation

        if mode != .hidden && !panel.isVisible {
            // Part de la taille de l'encoche pour que l'ouverture s'anime depuis elle.
            state.shapeSize = size(for: .hidden)
            state.shapeOffset = 0
        }
        let current = panel.isVisible ? panel.frame : frame(for: .hidden)
        placeWindow(current.union(targetFrame))
        if mode != .hidden && !panel.isVisible { panel.orderFrontRegardless() }
        panel.ignoresMouseEvents = (mode == .hidden)

        // Ouverture : ressort doux avec un léger rebond. Fermeture : plus courte, sans rebond.
        let anim: Animation = mode == .expanded
            ? .spring(duration: 0.5, bounce: 0.2)
            : .spring(duration: 0.36, bounce: 0)
        withAnimation(anim) {
            state.mode = mode
            state.shapeSize = target
            state.shapeOffset = offset(for: mode)
            state.rightEar = ear
            state.leftEar = leftEarWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.generation == gen else { return }
            if mode == .hidden {
                self.panel.orderOut(nil)
            } else {
                self.placeWindow(targetFrame)
            }
        }
    }
}
