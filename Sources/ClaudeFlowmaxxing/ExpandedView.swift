import SwiftUI

struct ExpandedView: View {
    @ObservedObject var state: AppState
    @ObservedObject var claude: ClaudeMonitor
    @ObservedObject var usage: UsageService
    @ObservedObject var cost: CostService
    @ObservedObject var spotify: SpotifyService

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
            MusicPage(spotify: spotify)
                .frame(width: w, alignment: .top)
        }
        .offset(x: base + state.pageDrag)
        .frame(width: w, alignment: .center)
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 14) {
            tab("Claude", 0)
            tab("Musique", 1)
            Spacer(minLength: state.notchWidth)
            Button {
                usage.refresh()
                cost.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Actualiser")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quitter Claude Flowmaxxing")
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
        let ouvertes = n == 0 ? "Aucune session ouverte" : (n == 1 ? "1 session ouverte" : "\(n) sessions ouvertes")
        if claude.busyNames.isEmpty { return ouvertes }
        return ouvertes + ", en cours : " + claude.busyNames.joined(separator: ", ")
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 8) {
                quotaTile(usage.fiveHour, title: "5 heures", slot: 0)
                quotaTile(usage.sevenDay, title: "7 jours", slot: 1)
                thirdTile
                Tile(title: "Coût du jour, en local",
                     value: Format.montant(cost.today, symbole: "$"),
                     subtitle: cost.projection.map { "environ \(Format.montant($0, symbole: "$")) d'ici ce soir" } ?? (cost.ready ? "journée terminée" : "calcul en cours"))
                creditsTile
                Tile(title: "Modèle principal",
                     value: cost.topModel ?? "…",
                     subtitle: cost.topModel == nil ? "aucune donnée" : "\(Format.pourcent(cost.topShare)) des dépenses sur 7 jours")
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
            Tile(title: "Coût sur 7 jours, en local",
                 value: Format.montant(cost.week, symbole: "$"),
                 subtitle: "au tarif public de l'API")
        }
    }

    @ViewBuilder private var creditsTile: some View {
        if let c = usage.credits {
            Tile(title: "Crédits supplémentaires",
                 value: Format.montant(c.used, symbole: c.symbole),
                 subtitle: creditsSubtitle(c),
                 accent: c.capReached ? Palette.level(100) : nil)
        } else {
            Tile(title: "Crédits supplémentaires",
                 value: usage.updated == nil ? "…" : "Désactivés",
                 subtitle: " ")
        }
    }

    private func creditsSubtitle(_ c: Credits) -> String {
        let plafond = c.limit.map { Format.montant($0, symbole: c.symbole) }
        if c.capReached { return plafond.map { "plafond de \($0) atteint" } ?? "plafond atteint" }
        if let p = c.percent, let plafond { return "\(Format.pourcent(p)) du plafond de \(plafond)" }
        return plafond.map { "sur \($0)" } ?? " "
    }

    private func quotaTile(_ q: Quota?, title: String, slot: Int) -> some View {
        let selected = state.notchSlot == slot
        return Tile(title: title,
                    value: q.map { Format.pourcent($0.percent) } ?? "…",
                    subtitle: q?.resetsAt.map { "remise à zéro dans \(Format.dureeAvant($0))" } ?? " ",
                    accent: q.map { Palette.level($0.percent) },
                    badge: selected ? "dans l'encoche" : nil,
                    selected: selected)
            .onTapGesture { state.notchSlot = slot }
            .help(selected ? "Affiché dans l'encoche" : "Cliquer pour afficher dans l'encoche")
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
    @ObservedObject var spotify: SpotifyService

    var body: some View {
        if !spotify.running {
            message("Spotify n'est pas ouvert.")
        } else if spotify.permissionDenied {
            message("Autorise Claude Flowmaxxing à piloter Spotify : Réglages Système, Confidentialité et sécurité, Automatisation.")
        } else if spotify.title.isEmpty {
            message("Aucun morceau en cours.")
        } else {
            HStack(spacing: 16) {
                Artwork(image: spotify.artwork, size: 120, radius: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text(spotify.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(spotify.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    progress
                    controls
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 124)
            .padding(.top, 4)
        }
    }

    private var progress: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(Color.white)
                        .frame(width: spotify.duration > 0 ? geo.size.width * min(1, spotify.position / spotify.duration) : 0)
                }
            }
            .frame(height: 4)
            HStack {
                Text(Format.minutesSecondes(spotify.position))
                Spacer()
                Text(Format.minutesSecondes(spotify.duration))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(Palette.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Spacer()
            control("backward.fill", 15) { spotify.previous() }
            control(spotify.isPlaying ? "pause.fill" : "play.fill", 20) { spotify.playPause() }
            control("forward.fill", 15) { spotify.next() }
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
