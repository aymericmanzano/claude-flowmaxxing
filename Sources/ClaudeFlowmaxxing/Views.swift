import SwiftUI

enum Palette {
    static let claude = Color(red: 0.851, green: 0.467, blue: 0.341)   // #D97757
    static let tile = Color.white.opacity(0.07)
    static let secondary = Color.white.opacity(0.55)
    static func level(_ p: Double) -> Color {
        if p >= 85 { return Color(red: 0.95, green: 0.33, blue: 0.35) }
        if p >= 60 { return Color(red: 0.96, green: 0.65, blue: 0.14) }
        return Color(red: 0.37, green: 0.83, blue: 0.71)
    }
}

// MARK: - Forme de l'encoche

struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var flare: CGFloat = AppDelegate.flare

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in r: CGRect) -> Path {
        let t = flare, b = min(bottomRadius, r.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.minY + t), control: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + t, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + t + b, y: r.maxY), control: CGPoint(x: r.minX + t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - t, y: r.maxY - b), control: CGPoint(x: r.maxX - t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - t, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Racine

struct RootView: View {
    @ObservedObject var state: AppState
    @ObservedObject var claude: ClaudeMonitor
    @ObservedObject var usage: UsageService
    @ObservedObject var cost: CostService
    @ObservedObject var music: MusicService

    var body: some View {
        let radius: CGFloat = state.mode == .expanded ? 22 : (state.mode == .toast ? 16 : 10)
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: radius)
                .fill(Color.black)
            content
                .padding(.horizontal, AppDelegate.flare)
        }
        .frame(width: state.shapeSize.width, height: state.shapeSize.height, alignment: .top)
        .clipped()
        .clipShape(NotchShape(bottomRadius: radius))
        .contentShape(NotchShape(bottomRadius: radius))
        .onTapGesture {
            if state.mode == .toast {
                state.openToastSession()
            } else if state.mode == .compact {
                state.page = 0
                state.expanded = true
            }
        }
        .offset(x: state.shapeOffset + state.contentShift)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    /// Les deux vues restent construites en permanence : rien n'est créé au moment du clic,
    /// ce qui évite l'à-coup de la première image. Leur apparition passe par le fondu,
    /// le flou et une légère mise à l'échelle depuis l'encoche.
    private var content: some View {
        let compact = state.mode == .compact || state.mode == .toast
        let toast = state.mode == .toast
        let open = state.mode == .expanded
        let width = max(0, state.shapeSize.width - 2 * AppDelegate.flare)
        // Le panneau est en surimpression : il ne pèse pas sur la largeur de l'encoche fermée.
        return CompactView(state: state, claude: claude, usage: usage, music: music)
            .frame(width: width, alignment: .top)
            .opacity(compact ? 1 : 0)
            .blur(radius: compact ? 0 : 4)
            .animation(compact ? .easeOut(duration: 0.22).delay(0.1) : .easeIn(duration: 0.1), value: compact)
            .allowsHitTesting(compact)
            .frame(width: width, alignment: .top)
            .overlay(alignment: .top) {
                FinishedBanner(name: state.toast ?? "")
                    .frame(width: width, height: AppDelegate.toastHeight)
                    .padding(.top, state.notchHeight)
                    .opacity(toast ? 1 : 0)
                    .blur(radius: toast ? 0 : 6)
                    .offset(y: toast ? 0 : -8)
                    .animation(toast ? .spring(duration: 0.4, bounce: 0.15).delay(0.08) : .easeIn(duration: 0.12), value: toast)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                ExpandedView(state: state, claude: claude, usage: usage, cost: cost, music: music)
                    .frame(width: AppDelegate.expandedSize.width - 2 * AppDelegate.flare,
                           height: AppDelegate.expandedSize.height, alignment: .top)
                    .opacity(open ? 1 : 0)
                    .blur(radius: open ? 0 : 10)
                    .scaleEffect(open ? 1 : 0.9, anchor: .top)
                    .offset(y: open ? 0 : -6)
                    .animation(open ? .spring(duration: 0.45, bounce: 0.12).delay(0.05) : .easeIn(duration: 0.12), value: open)
                    .allowsHitTesting(open)
            }
    }
}

// MARK: - Bandeau de fin

/// « Refactor du parseur a terminé » : affiché quelques secondes quand une réponse finit.
struct FinishedBanner: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Palette.level(0))
            Text(name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("a terminé")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.secondary)
                .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Encoche fermée

struct CompactView: View {
    @ObservedObject var state: AppState
    @ObservedObject var claude: ClaudeMonitor
    @ObservedObject var usage: UsageService
    @ObservedObject var music: MusicService

    /// À gauche, une oreille étroite pour le personnage seul, qui laisse visibles les menus
    /// de l'app au premier plan ; à droite, le quota et la pochette.
    var body: some View {
        // Marge qui aligne l'emplacement de l'encoche sur l'encoche physique, quelle que soit
        // la largeur de la forme (fermée et asymétrique, ou bandeau de fin, centré).
        let lead = max(0, (state.shapeSize.width - 2 * AppDelegate.flare) / 2 - state.shapeOffset
                          - state.notchWidth / 2 - state.leftEar)
        return HStack(spacing: 0) {
            Color.clear.frame(width: lead)
            HStack(spacing: 6) {
                if claude.visible {
                    ClaudeCreature(animated: claude.generating)
                        .frame(width: 20, height: 15)
                }
                if music.isPlaying {
                    Artwork(image: music.artwork, size: 18, radius: 4)
                        .onTapGesture { state.openMusic() }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 10)
            .frame(width: state.leftEar)
            Color.clear.frame(width: state.notchWidth)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if claude.visible {
                    QuotaBadge(quota: usage.quota(slot: state.notchSlot), short: usage.shortLabel(slot: state.notchSlot))
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { state.cycleSlot(usage) } }
                        .help("\(usage.shortLabel(slot: state.notchSlot)) : cliquer pour passer à 5 heures, 7 jours ou Fable")
                } else if music.isPlaying {
                    Equalizer().frame(width: 16, height: 13)
                }
            }
            .padding(.trailing, 7)
            .frame(width: state.rightEar)
            Spacer(minLength: 0)
        }
        .frame(height: state.notchHeight)
        .contentShape(Rectangle())
        .onTapGesture { state.page = 0; state.expanded = true }
    }
}

struct QuotaBadge: View {
    let quota: Quota?
    let short: String?

    var body: some View {
        HStack(spacing: 3) {
            if let short {
                // Raccourci s'il manque de place (« Fable ») ; le pourcentage et le rond restent entiers.
                Text(short)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
                    .foregroundStyle(Palette.secondary)
            }
            if let q = quota {
                Text(Format.pourcent(q.percent))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(.white)
                Ring(percent: q.percent, lineWidth: 2.5).frame(width: 13, height: 13)
            } else {
                Ring(percent: 0, lineWidth: 2.5).frame(width: 13, height: 13)
            }
        }
    }
}

struct Ring: View {
    let percent: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, percent / 100))
                .stroke(Palette.level(percent), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Personnage

/// Petit personnage en pixels, dessiné à la main. Les pattes bougent pendant une génération.
struct ClaudeCreature: View {
    let animated: Bool

    private static let body: [String] = [
        "..XXXXXXXX..",
        "..X.XXXX.X..",
        "XXXXXXXXXXXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
    ]
    private static let legsA: [String] = ["..X.X..X.X..", "..X.X..X.X.."]
    private static let legsB: [String] = ["...X.XX.X...", "...X.XX.X..."]

    var body: some View {
        if animated {
            TimelineView(.periodic(from: .now, by: 0.16)) { ctx in
                let frame = Int(ctx.date.timeIntervalSinceReferenceDate / 0.16) % 2
                sprite(legs: frame == 0 ? Self.legsA : Self.legsB, bob: frame == 0 ? 0 : -1)
            }
        } else {
            sprite(legs: Self.legsA, bob: 0).opacity(0.9)
        }
    }

    private func sprite(legs: [String], bob: CGFloat) -> some View {
        Canvas { ctx, size in
            let rows = Self.body + legs
            let cols = rows[0].count
            let px = min(size.width / CGFloat(cols), size.height / CGFloat(rows.count))
            let ox = (size.width - px * CGFloat(cols)) / 2
            let oy = (size.height - px * CGFloat(rows.count)) / 2
            for (y, row) in rows.enumerated() {
                let shift = y < Self.body.count ? bob * px * 0.5 : 0
                for (x, ch) in row.enumerated() where ch == "X" {
                    let rect = CGRect(x: ox + CGFloat(x) * px, y: oy + CGFloat(y) * px + shift,
                                      width: px + 0.3, height: px + 0.3)
                    ctx.fill(Path(rect), with: .color(Palette.claude))
                }
            }
        }
    }
}

struct Equalizer: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let h = 0.3 + 0.7 * abs(sin(t * (3.1 + Double(i) * 0.9) + Double(i)))
                    Capsule()
                        .fill(Color(red: 0.12, green: 0.84, blue: 0.38))
                        .frame(height: max(2, 13 * h))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note").font(.system(size: size * 0.45)).foregroundStyle(Palette.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
