import SwiftUI

struct ExpandedView: View {
    @ObservedObject var state: AppState
    @ObservedObject var claude: ClaudeMonitor
    @ObservedObject var usage: UsageService
    @ObservedObject var cost: CostService
    @ObservedObject var music: MusicService

    var body: some View {
        VStack(spacing: 10) {
            header
            pages
                .frame(maxHeight: .infinity, alignment: .top)
            dots
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    /// Les deux pages côte à côte : la bande glisse d'une page à l'autre et suit les doigts
    /// pendant un balayage à deux doigts.
    private var pages: some View {
        let w = AppDelegate.expandedSize.width - 2 * AppDelegate.flare - 32
        let gap: CGFloat = 32
        let base = state.page == 0 ? (w + gap) / 2 : -(w + gap) / 2
        return HStack(alignment: .top, spacing: gap) {
            ClaudePage(state: state, claude: claude, usage: usage, cost: cost)
                .frame(width: w, alignment: .top)
            MusicPage(music: music)
                .frame(width: w, alignment: .top)
        }
        .offset(x: base + state.pageDrag)
        .frame(width: w, alignment: .center)
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 14) {
            tab("Claude", 0)
            tab(L.s("tab.music"), 1)
            Spacer(minLength: state.notchWidth)
            Button {
                usage.refresh()
                cost.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L.s("help.refresh"))
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help(L.s("help.quit"))
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.secondary)
        .frame(height: state.notchHeight)
    }

    private func tab(_ label: String, _ index: Int) -> some View {
        Button(label) {
            withAnimation(.easeInOut(duration: 0.2)) { state.page = index }
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: state.page == index ? .semibold : .regular))
        .foregroundStyle(state.page == index ? Color.white : Palette.secondary)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(state.page == i ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { state.page = i } }
            }
        }
    }
}

// MARK: - Page Claude

struct ClaudePage: View {
    @ObservedObject var state: AppState
    @ObservedObject var claude: ClaudeMonitor
    @ObservedObject var usage: UsageService
    @ObservedObject var cost: CostService

    private var sessionsLine: String {
        let n = claude.openCount
        let ouvertes = n == 0 ? L.s("sessions.none") : (n == 1 ? L.s("sessions.one") : L.s("sessions.many", n))
        if claude.busyNames.isEmpty { return ouvertes }
        return L.s("sessions.busy", ouvertes, claude.busyNames.joined(separator: ", "))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 8) {
                quotaTile(usage.fiveHour, title: L.s("quota.5h"), slot: 0)
                quotaTile(usage.sevenDay, title: L.s("quota.7d"), slot: 1)
                thirdTile
                Tile(title: L.s("cost.today"),
                     value: Format.montant(cost.today, symbole: "$"),
                     subtitle: cost.projection.map { L.s("cost.projection", Format.montant($0, symbole: "$")) } ?? (cost.ready ? L.s("cost.dayOver") : L.s("cost.computing")))
                creditsTile
                Tile(title: L.s("model.title"),
                     value: cost.topModel ?? "…",
                     subtitle: cost.topModel == nil ? L.s("model.none") : L.s("model.share", Format.pourcent(cost.topShare)))
            }
            Group {
                if let e = usage.error {
                    Text(e).foregroundStyle(Color(red: 0.96, green: 0.65, blue: 0.14))
                } else {
                    Text(sessionsLine).foregroundStyle(Palette.secondary)
                }
            }
            .font(.system(size: 11))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var thirdTile: some View {
        if let q = usage.others.first {
            quotaTile(q, title: q.label, slot: 2)
        } else {
            Tile(title: L.s("cost.week"),
                 value: Format.montant(cost.week, symbole: "$"),
                 subtitle: L.s("cost.apiRates"))
        }
    }

    @ViewBuilder private var creditsTile: some View {
        if let c = usage.credits {
            Tile(title: L.s("credits.title"),
                 value: Format.montant(c.used, symbole: c.symbole),
                 subtitle: creditsSubtitle(c),
                 accent: c.capReached ? Palette.level(100) : nil)
        } else {
            Tile(title: L.s("credits.title"),
                 value: usage.updated == nil ? "…" : L.s("credits.off"),
                 subtitle: " ")
        }
    }

    private func creditsSubtitle(_ c: Credits) -> String {
        let plafond = c.limit.map { Format.montant($0, symbole: c.symbole) }
        if c.capReached { return plafond.map { L.s("credits.capOf", $0) } ?? L.s("credits.cap") }
        if let p = c.percent, let plafond { return L.s("credits.pctOf", Format.pourcent(p), plafond) }
        return plafond.map { L.s("credits.of", $0) } ?? " "
    }

    private func quotaTile(_ q: Quota?, title: String, slot: Int) -> some View {
        let selected = state.notchSlot == slot
        return Tile(title: title,
                    value: q.map { Format.pourcent($0.percent) } ?? "…",
                    subtitle: q?.resetsAt.map { L.s("quota.reset", Format.dureeAvant($0)) } ?? " ",
                    accent: q.map { Palette.level($0.percent) },
                    badge: selected ? L.s("quota.badge") : nil,
                    selected: selected)
            .onTapGesture { state.notchSlot = slot }
            .help(selected ? L.s("quota.shown") : L.s("quota.clickToShow"))
    }
}

struct Tile: View {
    let title: String
    let value: String
    let subtitle: String
    var accent: Color? = nil
    var badge: String? = nil
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.85)))
                }
            }
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let accent {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
            }
            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.tile)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(selected ? 0.35 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Page Musique

struct MusicPage: View {
    @ObservedObject var music: MusicService

    var body: some View {
        if !music.running {
            // Autre app (Deezer, Tidal, navigateur…) : pas d'infos, mais les touches multimédia.
            VStack(spacing: 14) {
                Text(L.s("music.closed"))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
                controls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if music.permissionDenied {
            message(L.s("music.permission", music.appName))
        } else if music.title.isEmpty {
            message(L.s("music.nothing"))
        } else {
            // Pochette à pleine hauteur ; à côté, de haut en bas : l'app, le morceau,
            // la progression et les boutons, alignés sur la hauteur de la pochette.
            HStack(alignment: .center, spacing: 18) {
                Artwork(image: music.artwork, size: 150, radius: 14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(music.appName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Palette.secondary)
                        .padding(.bottom, 6)
                    Text(music.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(music.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                    Spacer(minLength: 10)
                    progress
                    controls
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .frame(maxHeight: .infinity)
        }
    }

    private var progress: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(Color.white)
                        .frame(width: music.duration > 0 ? geo.size.width * min(1, music.position / music.duration) : 0)
                }
            }
            .frame(height: 4)
            HStack {
                Text(Format.minutesSecondes(music.position))
                Spacer()
                Text(Format.minutesSecondes(music.duration))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(Palette.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 36) {
            Spacer()
            control("backward.fill", 17) { music.previous() }
            control(music.isPlaying ? "pause.fill" : "play.fill", 24) { music.playPause() }
            control("forward.fill", 17) { music.next() }
            Spacer()
        }
    }

    private func control(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func message(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 13))
            .foregroundStyle(Palette.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
