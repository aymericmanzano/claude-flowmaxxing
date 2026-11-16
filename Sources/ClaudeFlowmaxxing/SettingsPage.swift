import SwiftUI
import ServiceManagement

/// Réglages ouverts par la roue crantée, dans le panneau : alertes, projection,
/// ouverture au démarrage, crédit et version.
struct SettingsPage: View {
    @AppStorage(Settings.weekAlert) private var weekAlert = true
    @AppStorage(Settings.projectionAlert) private var projectionAlert = true
    @AppStorage(Settings.fiveAlert) private var fiveAlert = true
    @AppStorage(Settings.lastDay) private var lastDay = false
    @State private var loginOn = SMAppService.mainApp.status == .enabled

    private var inApplications: Bool { Bundle.main.bundlePath.hasPrefix("/Applications/") }
    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
    }

    var body: some View {
        VStack(spacing: 12) {
            group {
                toggleRow(L.s("set.weekly"), $weekAlert)
                divider
                toggleRow(L.s("set.projectionAlert"), $projectionAlert)
                divider
                toggleRow(L.s("set.fiveAlert"), $fiveAlert)
            }
            group {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L.s("set.projection")).foregroundStyle(.white)
                        Text(L.s("set.projection.sub")).font(.system(size: 11.5)).foregroundStyle(Palette.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 2) {
                        modeButton(L.s("set.mode.week"), selected: !lastDay) { lastDay = false }
                        modeButton("24 h", selected: lastDay) { lastDay = true }
                    }
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                }
                .frame(height: 46)
                divider
                toggleRow(L.s("set.login"), Binding(get: { loginOn }, set: setLogin(_:)), enabled: inApplications)
                    .help(inApplications ? "" : L.s("set.login.help"))
            }
            HStack(spacing: 4) {
                Text(L.s("set.credit", version))
                Spacer(minLength: 4)
                Button("aymericmanzano.fr") {
                    if let url = URL(string: "https://aymericmanzano.fr") { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.claude)
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.secondary)
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
        .font(.system(size: 13.5))
        .onAppear { loginOn = SMAppService.mainApp.status == .enabled }
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.tile))
    }

    private var divider: some View { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }

    private func toggleRow(_ label: String, _ value: Binding<Bool>, enabled: Bool = true) -> some View {
        HStack {
            Text(label).foregroundStyle(enabled ? .white : Palette.secondary).lineLimit(1)
            Spacer(minLength: 8)
            FlowSwitch(isOn: value, enabled: enabled)
        }
        .frame(height: 40)
    }

    private func modeButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Palette.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Color.white.opacity(0.18) : .clear))
        }
        .buttonStyle(.plain)
    }

    /// Ouverture au démarrage : seulement depuis /Applications, pour ne pas inscrire une copie de travail.
    private func setLogin(_ on: Bool) {
        guard inApplications else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            Log.write("ouverture au démarrage : \(on ? "activée" : "retirée") depuis les réglages")
        } catch {
            Log.write("ouverture au démarrage : échec (\(error.localizedDescription))")
        }
        loginOn = SMAppService.mainApp.status == .enabled
    }
}

/// Interrupteur dessiné : le panneau n'est jamais la fenêtre active, et l'interrupteur
/// du système y reste gris même allumé.
struct FlowSwitch: View {
    @Binding var isOn: Bool
    var enabled = true

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? Palette.good : Color.white.opacity(0.18))
            Circle().fill(.white).padding(2.5).shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: 40, height: 23)
        .opacity(enabled ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard enabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() }
        }
    }
}
