import SwiftUI

// MARK: - Page Tableau

/// Courbes des fenêtres de 5 heures et de la semaine, puis ce qui consomme la semaine.
/// Le panneau s'agrandit sur cet onglet (voir `AppDelegate.tallHeight`).
struct BoardPage: View {
    @ObservedObject var usage: UsageService
    @ObservedObject var cost: CostService
    @AppStorage(Settings.lastDay) private var lastDay = false

    var body: some View {
        let five = Forecast.make(usage.fiveHour, kind: .five, samples: usage.samples, costBuckets: cost.buckets)
        let week = Forecast.make(usage.sevenDay, kind: .seven, samples: usage.samples,
                                 costBuckets: cost.buckets, lastDay: lastDay)
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ChartCard(kind: .five, title: L.s("board.5h"), forecast: five,
                          subtitle: five.map { L.s("quota.reset", Format.dureeAvant($0.end)) })
                ChartCard(kind: .seven, title: L.s("board.week"), forecast: week,
                          subtitle: week.map { L.s("board.resetAt", Format.jourCourt($0.end), Format.heure($0.end)) },
                          detail: week.map { L.s("board.budget", Format.pourcent1($0.perDay)) })
            }
            .frame(height: 212)
            HStack(spacing: 10) {
                groupsCard
                statsCard.frame(width: 190)
            }
        }
    }

    private var groupsCard: some View {
        let groups = cost.weekStats.groups
        return VStack(alignment: .leading, spacing: 6) {
            Text(L.s("board.usage")).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            if groups.isEmpty {
                Text(cost.ready ? L.s("board.nodata") : L.s("cost.computing"))
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            } else {
                ForEach(Array(groups.prefix(6).enumerated()), id: \.offset) { _, g in
                    HStack(spacing: 10) {
                        Text(g.name).lineLimit(1).truncationMode(.tail)
                            .frame(width: 120, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(Palette.claude)
                                    .frame(width: max(3, geo.size.width * min(1, g.share / 100)))
                            }
                        }
                        .frame(height: 7)
                        Text(Format.pourcent(g.share)).monospacedDigit()
                            .foregroundStyle(Palette.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white)
                    .help("\(g.name) : \(Format.pourcent1(g.share))")
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.tile))
    }

    private var statsCard: some View {
        let s = cost.weekStats
        return VStack(alignment: .leading, spacing: 10) {
            stat(Format.grandNombre(s.tokens), L.s("board.tokens"))
            stat(Format.montant(s.cost, symbole: "$"), L.s("board.api"))
            stat(Format.grandNombre(Double(s.calls)),
                 s.topFamily.map { L.s("board.calls", Format.pourcent(s.topFamilyShare), $0) } ?? L.s("board.callsOnly"))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.tile))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11.5)).foregroundStyle(Palette.secondary).lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

/// Carte d'une fenêtre : pourcentage restant, avance ou retard, courbe et projection.
/// Au survol de la courbe, la valeur à la date pointée remplace le sous-titre.
struct ChartCard: View {
    let kind: Forecast.Kind
    let title: String
    let forecast: Forecast?
    let subtitle: String?
    /// Information secondaire à droite du pourcentage (budget par jour de la semaine).
    var detail: String? = nil
    @State private var hover: (date: Date, used: Double, projected: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 12.5)).foregroundStyle(Palette.secondary).lineLimit(1)
                Spacer(minLength: 0)
                if let f = forecast { PaceBadge(gap: f.gap) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(forecast.map { Format.pourcent($0.left) } ?? "…")
                    .font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white)
                Text(L.s("board.left")).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                if let detail {
                    Spacer(minLength: 6)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Palette.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            Text(hoverText ?? subtitle ?? " ")
                .font(.system(size: 11.5, weight: hover == nil ? .regular : .semibold))
                .foregroundStyle(hover == nil ? Palette.secondary : Color.white)
                .lineLimit(1).minimumScaleFactor(0.8)
            if let f = forecast {
                QuotaChart(forecast: f, kind: kind, hover: $hover)
                    .padding(.top, 4)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.tile))
    }

    private var hoverText: String? {
        guard let h = hover else { return nil }
        let when = kind == .five ? Format.heure(h.date) : "\(Format.jourCourt(h.date)) \(Format.heure(h.date))"
        let value = Format.pourcent(max(0, 100 - h.used))
        return h.projected ? L.s("board.hoverForecast", when, value) : L.s("board.hover", when, value)
    }
}

struct PaceBadge: View {
    let gap: Double
    var body: some View {
        let ahead = gap >= 0
        let value = Format.pourcent1(abs(gap)).replacingOccurrences(of: "%", with: "")
        Text(ahead ? L.s("board.ahead", value) : L.s("board.behind", value))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ahead ? Palette.good : Palette.bad)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill((ahead ? Palette.good : Palette.bad).opacity(0.15)))
            .lineLimit(1)
            .help(ahead ? L.s("board.aheadHelp") : L.s("board.behindHelp"))
    }
}

/// Courbe du pourcentage restant : rythme régulier en pointillé, écart coloré,
/// projection jusqu'au renouvellement ou jusqu'à zéro, puis zone bloquée hachurée.
struct QuotaChart: View {
    let forecast: Forecast
    let kind: Forecast.Kind
    @Binding var hover: (date: Date, used: Double, projected: Bool)?
    @State private var hoverX: CGFloat?

    private static let top: CGFloat = 14, bottom: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in draw(&ctx, size) }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p):
                        let x = min(max(0, p.x), geo.size.width)
                        hoverX = x
                        hover = value(atX: x, width: geo.size.width)
                    case .ended:
                        hoverX = nil
                        hover = nil
                    }
                }
        }
    }

    private func date(atX x: CGFloat, width: CGFloat) -> Date {
        forecast.start.addingTimeInterval(Double(x / max(1, width)) * forecast.duration)
    }

    /// Valeur à une position : la courbe réelle avant maintenant, la projection après.
    private func value(atX x: CGFloat, width: CGFloat) -> (date: Date, used: Double, projected: Bool) {
        let f = forecast
        let d = date(atX: x, width: width)
        if d <= f.now {
            var used = f.points.first?.1 ?? 0
            for (i, p) in f.points.enumerated() where p.0 <= d {
                used = p.1
                if i + 1 < f.points.count, f.points[i + 1].0 > d {
                    let n = f.points[i + 1], span = n.0.timeIntervalSince(p.0)
                    if span > 0 { used = p.1 + (n.1 - p.1) * d.timeIntervalSince(p.0) / span }
                }
            }
            return (d, used, false)
        }
        return (d, min(100, f.used + f.rate * d.timeIntervalSince(f.now) / 3600), true)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let f = forecast
        let top = Self.top, bottom = Self.bottom
        let h = size.height - top - bottom, w = size.width
        func x(_ d: Date) -> CGFloat { CGFloat(d.timeIntervalSince(f.start) / f.duration) * w }
        func y(_ used: Double) -> CGFloat { top + CGFloat(used / 100) * h }   // restant : 100% en haut
        let ahead = f.gap >= 0
        let projColor = ahead ? Palette.claude : Palette.bad
        let small = Font.system(size: 10.5, weight: .semibold)

        for v in [0.0, 50.0, 100.0] {
            var p = Path(); p.move(to: CGPoint(x: 0, y: y(v))); p.addLine(to: CGPoint(x: w, y: y(v)))
            ctx.stroke(p, with: .color(.white.opacity(v == 50 ? 0.05 : 0.09)), lineWidth: 1)
        }

        // Zone bloquée.
        if f.runsOut, let z = f.zeroDate {
            let rect = CGRect(x: x(z), y: top, width: w - x(z), height: h)
            ctx.fill(Path(rect), with: .color(Palette.bad.opacity(0.08)))
            var hatch = Path()
            var s = rect.minX - rect.height
            while s < rect.maxX { hatch.move(to: CGPoint(x: s, y: rect.maxY)); hatch.addLine(to: CGPoint(x: s + rect.height, y: rect.minY)); s += 6 }
            var clip = ctx; clip.clip(to: Path(rect))
            clip.stroke(hatch, with: .color(Palette.bad.opacity(0.45)), lineWidth: 1)
            if rect.width > 38 {
                ctx.draw(Text(L.s("board.locked")).font(small).foregroundColor(Palette.badText),
                         at: CGPoint(x: rect.midX, y: rect.midY - 7))
                ctx.draw(Text(Self.hours(f.lockHours)).font(small).foregroundColor(Palette.badText),
                         at: CGPoint(x: rect.midX, y: rect.midY + 7))
            }
        }

        // Écart avec le rythme régulier.
        var gapArea = Path()
        gapArea.move(to: CGPoint(x: x(f.points[0].0), y: y(f.points[0].1)))
        for (d, v) in f.points { gapArea.addLine(to: CGPoint(x: x(d), y: y(v))) }
        for (d, _) in f.points.reversed() {
            gapArea.addLine(to: CGPoint(x: x(d), y: y(d.timeIntervalSince(f.start) / f.duration * 100)))
        }
        gapArea.closeSubpath()
        ctx.fill(gapArea, with: .color((ahead ? Palette.good : Palette.bad).opacity(0.22)))

        // Rythme régulier.
        var even = Path(); even.move(to: CGPoint(x: 0, y: y(0))); even.addLine(to: CGPoint(x: w, y: y(100)))
        ctx.stroke(even, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Projection.
        let endDate = f.runsOut ? f.zeroDate! : f.end
        let endUsed = f.runsOut ? 100 : f.usedAtReset
        let endPoint = CGPoint(x: x(endDate), y: y(endUsed))
        var proj = Path(); proj.move(to: CGPoint(x: x(f.now), y: y(f.used))); proj.addLine(to: endPoint)
        ctx.stroke(proj, with: .color(projColor), style: StrokeStyle(lineWidth: 1.8, dash: [5, 3]))
        let dot = Path(ellipseIn: CGRect(x: endPoint.x - 3, y: endPoint.y - 3, width: 6, height: 6))
        ctx.fill(dot, with: .color(.black)); ctx.stroke(dot, with: .color(projColor), lineWidth: 1.6)
        let endLabel = f.runsOut
            ? L.s("board.empty", Format.jourCourt(endDate).components(separatedBy: " ").first ?? "", Format.heure(endDate))
            : L.s("board.atEnd", Format.pourcent(100 - f.usedAtReset))
        Self.label(&ctx, Text(endLabel).font(small).foregroundColor(f.runsOut ? Palette.badText : Palette.claude),
                   at: CGPoint(x: min(endPoint.x, w) - 7, y: max(top + 5, endPoint.y - 11)), anchor: .trailing)

        // Courbe réelle et repère « maintenant ».
        var line = Path()
        for (i, (d, v)) in f.points.enumerated() {
            let pt = CGPoint(x: x(d), y: y(v))
            if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
        }
        ctx.stroke(line, with: .color(Palette.claude), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        var nowLine = Path(); nowLine.move(to: CGPoint(x: x(f.now), y: top)); nowLine.addLine(to: CGPoint(x: x(f.now), y: top + h))
        ctx.stroke(nowLine, with: .color(Palette.claude.opacity(0.45)), lineWidth: 1)
        ctx.fill(Path(ellipseIn: CGRect(x: x(f.now) - 3.5, y: y(f.used) - 3.5, width: 7, height: 7)), with: .color(Palette.claude))
        ctx.draw(Text(L.s("board.now")).font(small).foregroundColor(Palette.claude),
                 at: CGPoint(x: min(max(x(f.now), 30), w - 30), y: top - 7))

        // Axe : début et fin de la fenêtre.
        let axisFont = Font.system(size: 10.5)
        let a0 = kind == .five ? Format.heure(f.start) : Format.jourCourt(f.start)
        let a1 = kind == .five ? Format.heure(f.end) : "\(Format.jourCourt(f.end)) \(Format.heure(f.end))"
        ctx.draw(Text(a0).font(axisFont).foregroundColor(.white.opacity(0.45)), at: CGPoint(x: 0, y: size.height - 6), anchor: .leading)
        ctx.draw(Text(a1).font(axisFont).foregroundColor(.white.opacity(0.45)), at: CGPoint(x: w, y: size.height - 6), anchor: .trailing)

        // Survol : repère vertical et point sur la courbe.
        if let hx = hoverX {
            let v0 = value(atX: hx, width: w)
            var v = Path(); v.move(to: CGPoint(x: hx, y: top)); v.addLine(to: CGPoint(x: hx, y: top + h))
            ctx.stroke(v, with: .color(.white.opacity(0.6)), lineWidth: 1)
            let c = Path(ellipseIn: CGRect(x: hx - 4, y: y(v0.used) - 4, width: 8, height: 8))
            ctx.fill(c, with: .color(v0.projected ? .black : .white))
            ctx.stroke(c, with: .color(.white), lineWidth: 1.5)
        }
    }

    /// Étiquette sur fond sombre, lisible par-dessus les traits.
    private static func label(_ ctx: inout GraphicsContext, _ text: Text, at p: CGPoint, anchor: UnitPoint) {
        let r = ctx.resolve(text)
        let size = r.measure(in: CGSize(width: 300, height: 30))
        let origin = CGPoint(x: p.x - size.width * anchor.x, y: p.y - size.height * anchor.y)
        let bg = CGRect(origin: origin, size: size).insetBy(dx: -3, dy: -1)
        ctx.fill(Path(roundedRect: bg, cornerRadius: 3), with: .color(Color(white: 0.07)))
        ctx.draw(r, at: p, anchor: anchor)
    }

    private static func hours(_ h: Double) -> String {
        let total = Int(h.rounded())
        return total >= 24 ? L.s("dur.dh", total / 24, total % 24) : "\(total) h"
    }
}

/// Ligne rouge de la page Claude, affichée seulement quand la semaine finit avant son renouvellement.
struct WeekAlertLine: View {
    @ObservedObject var state: AppState
    @ObservedObject var usage: UsageService
    @ObservedObject var cost: CostService
    @AppStorage(Settings.lastDay) private var lastDay = false

    var body: some View {
        if let f = Forecast.make(usage.sevenDay, kind: .seven, samples: usage.samples,
                                 costBuckets: cost.buckets, lastDay: lastDay),
           f.runsOut, let z = f.zeroDate {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.bad)
                Text(L.s("alert.line", Format.jour(z), Format.heure(z), Format.pourcent1(f.perDay)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.bad.opacity(0.18)))
            .onAppear { if !state.weekAlert { state.weekAlert = true } }
            .onDisappear { if state.weekAlert { state.weekAlert = false } }
        }
    }
}

extension Palette {
    static let good = Color(red: 0.30, green: 0.76, blue: 0.54)
    static let bad = Color(red: 0.94, green: 0.39, blue: 0.36)
    static let badText = Color(red: 1.0, green: 0.54, blue: 0.51)
}
