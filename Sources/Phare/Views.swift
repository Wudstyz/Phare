import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum Theme {
    static let navy = Color(red: 0.07, green: 0.19, blue: 0.29)
    static let teal = Color(red: 0.11, green: 0.64, blue: 0.61)
    static let amber = Color(red: 0.96, green: 0.72, blue: 0.24)
    static let bg = Color(red: 0.965, green: 0.973, blue: 0.98)
    static let card = Color.white
    static let ok = Color(red: 0.16, green: 0.58, blue: 0.33)
    static let warn = Color(red: 0.85, green: 0.5, blue: 0.08)
    static let fail = Color(red: 0.8, green: 0.2, blue: 0.2)
    static let muted = Color(red: 0.4, green: 0.46, blue: 0.52)

    static func score(_ s: Int) -> Color { s >= 80 ? ok : (s >= 50 ? warn : fail) }
    static func status(_ s: Status) -> Color {
        switch s {
        case .ok: return ok
        case .warn: return warn
        case .fail: return fail
        case .info: return muted
        }
    }
    static func symbol(_ s: Status) -> String {
        switch s {
        case .ok: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case priorities = "Priorités"
    case seo = "SEO"
    case gso = "GSO"
    case ia = "Accès IA"
    case sheet = "Fiche technique"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var urlText = ""
    @Published var report: Report?
    @Published var running = false
    @Published var errorMessage: String?
    @Published var tab: Tab = .priorities

    func analyze() { start(demo: false) }

    func demo() {
        urlText = DemoData.url
        start(demo: true)
    }

    private func start(demo: Bool) {
        guard !running else { return }
        errorMessage = nil
        running = true
        let input = urlText
        Task {
            do {
                let analyzer = Analyzer(fetch: demo ? DemoData.fetch : liveFetch, isDemo: demo)
                let r = try await analyzer.run(input)
                report = r
                tab = .priorities
            } catch {
                errorMessage = error.localizedDescription
            }
            running = false
        }
    }

    func export() {
        guard let r = report else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "rapport-phare.md"
        panel.title = "Exporter le rapport"
        if panel.runModal() == .OK, let u = panel.url {
            try? r.markdown().write(to: u, atomically: true, encoding: .utf8)
        }
    }
}

struct ScoreRing: View {
    let title: String
    let subtitle: String
    let score: Int
    var big = false

    var body: some View {
        let size: CGFloat = big ? 120 : 84
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.black.opacity(0.07), lineWidth: big ? 12 : 9)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(Theme.score(score), style: StrokeStyle(lineWidth: big ? 12 : 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: big ? 38 : 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.navy)
            }
            .frame(width: size, height: size)
            Text(title).font(.headline).foregroundColor(Theme.navy)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 150)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CheckRow: View {
    let check: Check
    var showPillar = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Theme.symbol(check.status))
                .foregroundColor(Theme.status(check.status))
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(check.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.navy)
                    if showPillar {
                        Text(check.pillar.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.teal.opacity(0.15))
                            .foregroundColor(Theme.teal)
                            .clipShape(Capsule())
                    }
                }
                Text(check.detail).font(.system(size: 13)).foregroundColor(Theme.muted)
                if let a = check.advice {
                    Text("→ \(a)").font(.system(size: 13)).foregroundColor(Theme.navy)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06)))
    }
}

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let r = model.report {
                results(r)
            } else {
                welcome
            }
        }
        .frame(minWidth: 860, minHeight: 640)
        .background(Theme.bg)
        .preferredColorScheme(.light)
        .onAppear {
            if CommandLine.arguments.contains("--open-demo") { model.demo() }
            if let a = CommandLine.arguments.first(where: { $0.hasPrefix("--tab=") }),
               let t = Tab(rawValue: String(a.dropFirst(6))) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { model.tab = t }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 40, height: 40)
            Text("Phare").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(Theme.navy)
            TextField("https://www.monsite.fr", text: $model.urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .onSubmit { model.analyze() }
            Button {
                model.analyze()
            } label: {
                Text(model.running ? "Analyse…" : "Analyser").frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.teal)
            .disabled(model.running || model.urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Essayer la démo") { model.demo() }
                .disabled(model.running)
            if model.running { ProgressView().controlSize(.small) }
        }
        .padding(14)
        .background(Theme.card)
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128)
            Text("Éclairez votre site pour Google et pour les IA")
                .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(Theme.navy)
            Text("Collez l'adresse d'un site : Phare vérifie son SEO (Google, Bing), sa préparation GSO (être cité par ChatGPT, Claude, Perplexity, Gemini…) et l'accès des robots d'IA, puis vous donne les corrections à faire en priorité.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.muted)
                .frame(maxWidth: 560)
            if let e = model.errorMessage {
                Text(e).foregroundColor(Theme.fail).multilineTextAlignment(.center).frame(maxWidth: 560)
            }
            Text("Aucune donnée n'est envoyée à un tiers : l'analyse se fait depuis votre Mac. Pas de site sous la main ? Essayez la démo, elle fonctionne sans Internet.")
                .font(.caption).foregroundColor(Theme.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 520)
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func results(_ r: Report) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                ScoreRing(title: "Score global", subtitle: Report.grade(r.globalScore), score: r.globalScore, big: true)
                ForEach(Pillar.allCases) { p in
                    ScoreRing(title: p.rawValue, subtitle: p.subtitle, score: r.score(p))
                }
            }
            .padding(.vertical, 18).padding(.horizontal, 20)

            HStack {
                Picker("", selection: $model.tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Button("Exporter le rapport…") { model.export() }
            }
            .padding(.horizontal, 20).padding(.bottom, 10)

            if let e = model.errorMessage {
                Text(e).foregroundColor(Theme.fail).padding(.bottom, 6)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if r.isDemo {
                        Text("Mode démo : site fictif analysé sans connexion Internet.")
                            .font(.caption).foregroundColor(Theme.muted)
                    }
                    tabContent(r)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ r: Report) -> some View {
        switch model.tab {
        case .priorities:
            if r.priorities.isEmpty {
                Text("Rien à corriger : bravo !").foregroundColor(Theme.ok).padding()
            }
            ForEach(r.priorities) { CheckRow(check: $0, showPillar: true) }
        case .seo: ForEach(r.checks.filter { $0.pillar == .seo }) { CheckRow(check: $0) }
        case .gso: ForEach(r.checks.filter { $0.pillar == .gso }) { CheckRow(check: $0) }
        case .ia: ForEach(r.checks.filter { $0.pillar == .ia }) { CheckRow(check: $0) }
        case .sheet:
            VStack(spacing: 0) {
                ForEach(r.facts) { f in
                    HStack(alignment: .top) {
                        Text(f.label).foregroundColor(Theme.muted).frame(width: 200, alignment: .leading)
                        Text(f.value).foregroundColor(Theme.navy).textSelection(.enabled)
                        Spacer()
                    }
                    .padding(12)
                    Divider()
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct PhareApp: App {
    init() {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    var body: some Scene {
        WindowGroup("Phare") {
            ContentView()
        }
        .defaultSize(width: 980, height: 760)
    }
}
