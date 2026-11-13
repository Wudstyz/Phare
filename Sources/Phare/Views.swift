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

enum SiteTab: String, CaseIterable, Identifiable {
    case pages = "Pages"
    case recurring = "Problèmes récurrents"
    case linking = "Maillage"
    case backlinks = "Backlinks"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var urlText = ""
    @Published var report: Report?          // analyse d'une seule page
    @Published var site: SiteReport?        // analyse de tout le site
    @Published var detail: PageResult?      // page ouverte depuis le tableau
    @Published var siteMode = false
    @Published var maxPages = 50
    @Published var running = false
    @Published var progress: (Int, Int)?
    @Published var errorMessage: String?
    @Published var tab: Tab = .priorities
    @Published var siteTab: SiteTab = .pages
    @Published var backlinks: BacklinkData?
    @Published var exportNotice: String?
    @Published var promoDismissed = false

    func openPromo() {
        if let u = URL(string: "https://www.hpi-innovations.fr/?utm_source=phare&utm_medium=app&utm_campaign=bandeau") {
            NSWorkspace.shared.open(u)
        }
    }

    func openPromoMail() {
        let subject = "Correction de mon site (via Phare)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "mailto:damien@hpi-innovations.fr?subject=\(subject)") { NSWorkspace.shared.open(u) }
    }

    func analyze() { start(demo: false) }

    func importBacklinks() {
        let panel = NSOpenPanel()
        panel.title = "Choisir l'export « Liens externes » de Google Search Console"
        panel.message = "Un ou plusieurs fichiers .csv, ou le .zip téléchargé."
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .zip, .plainText]
        guard panel.runModal() == .OK else { return }
        backlinks = BacklinkParser.load(urls: panel.urls)
    }

    func clearBacklinks() { backlinks = nil }

    private func exportSite(_ s: SiteReport) {
        let panel = NSOpenPanel()
        panel.title = "Exporter le rapport complet"
        panel.message = "Choisissez où créer le dossier d'export (rapport global, un rapport par page, tableaux CSV)."
        panel.prompt = "Exporter ici"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        do {
            let dir = try SiteExporter.write(site: s, backlinks: backlinks, into: parent)
            exportNotice = "Export créé : « \(dir.lastPathComponent) » (\(s.pages.count) rapports de page + rapport global + 2 tableaux CSV)."
            NSWorkspace.shared.activateFileViewerSelecting([dir])
        } catch {
            errorMessage = "L'export a échoué : \(error.localizedDescription)"
        }
    }

    func demo() {
        urlText = DemoData.url
        start(demo: true)
    }

    func open(_ page: PageResult) {
        tab = .priorities
        detail = page
    }

    private func start(demo: Bool) {
        guard !running else { return }
        errorMessage = nil
        exportNotice = nil
        running = true
        progress = nil
        let input = urlText
        let wantSite = siteMode
        let limit = maxPages
        Task {
            do {
                let analyzer = Analyzer(fetch: demo ? DemoData.fetch : liveFetch, isDemo: demo)
                if wantSite {
                    let s = try await analyzer.runSite(input, maxPages: limit) { [weak self] done, total in
                        self?.progress = (done, total)
                    }
                    site = s
                    report = nil
                    detail = nil
                    siteTab = .pages
                    backlinks = demo ? BacklinkParser.parse(files: DemoData.backlinkFiles) : nil
                } else {
                    let r = try await analyzer.run(input)
                    report = r
                    site = nil
                    detail = nil
                    tab = .priorities
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            running = false
            progress = nil
        }
    }

    /// Site entier : dossier complet (global + une page par fichier + CSV). Page ouverte depuis le tableau : son rapport détaillé.
    /// Analyse d'une seule page : un fichier Markdown.
    func export() {
        errorMessage = nil
        exportNotice = nil
        let text: String
        let name: String
        if let s = site, let d = detail {
            text = s.pageMarkdown(d, backlinks: backlinks, back: nil)
            name = "rapport-phare-\(SiteExporter.slug(d.path)).md"
        } else if let s = site {
            exportSite(s)
            return
        } else if let d = report {
            text = d.markdown()
            name = "rapport-phare.md"
        } else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = name
        panel.title = "Exporter le rapport"
        if panel.runModal() == .OK, let u = panel.url {
            try? text.write(to: u, atomically: true, encoding: .utf8)
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
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 150)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PillarBadge: View {
    let pillar: Pillar
    var body: some View {
        Text(pillar.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.teal.opacity(0.15))
            .foregroundColor(Theme.teal)
            .clipShape(Capsule())
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
                    if showPillar { PillarBadge(pillar: check.pillar) }
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
            if (model.report != nil || model.site != nil) && !model.promoDismissed {
                promoBanner
            }
            if let r = model.detail?.report ?? model.report {
                results(r)
            } else if let s = model.site {
                siteView(s)
            } else {
                welcome
            }
        }
        .frame(minWidth: 940, minHeight: 640)
        .background(Theme.bg)
        .preferredColorScheme(.light)
        .onAppear {
            let args = CommandLine.arguments
            if args.contains("--site") { model.siteMode = true }
            if args.contains("--open-demo") { model.demo() }
            if let a = args.first(where: { $0.hasPrefix("--tab=") }), let t = Tab(rawValue: String(a.dropFirst(6))) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { model.tab = t }
            }
            if let a = args.first(where: { $0.hasPrefix("--sitetab=") }), let t = SiteTab(rawValue: String(a.dropFirst(10))) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { model.siteTab = t }
            }
            if let a = args.first(where: { $0.hasPrefix("--detail=") }), let i = Int(a.dropFirst(9)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if let s = model.site, i < s.pages.count { model.open(s.pages[i]) }
                }
            }
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 40, height: 40)
            Text("Phare").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(Theme.navy)
            TextField("https://www.monsite.fr", text: $model.urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .onSubmit { model.analyze() }
            Picker("", selection: $model.siteMode) {
                Text("Une page").tag(false)
                Text("Tout le site").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .disabled(model.running)
            .help("« Tout le site » lit le sitemap et analyse plusieurs pages.")
            if model.siteMode {
                Picker("", selection: $model.maxPages) {
                    ForEach([20, 50, 100, 200], id: \.self) { Text("\($0) pages max").tag($0) }
                }
                .labelsHidden()
                .frame(width: 125)
                .disabled(model.running)
            }
            Button {
                model.analyze()
            } label: {
                Text(model.running ? "Analyse…" : "Analyser").frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.teal)
            .disabled(model.running || model.urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Essayer la démo") { model.demo() }
                .disabled(model.running)
            if model.running {
                ProgressView().controlSize(.small)
                if let p = model.progress {
                    Text("\(p.0)/\(p.1)").font(.caption).foregroundColor(Theme.muted).monospacedDigit()
                }
            }
        }
        .padding(14)
        .background(Theme.card)
    }

    // MARK: Bandeau

    /// Bandeau discret affiché une fois les résultats obtenus. Fermable. Ouvre le site dans le navigateur au clic (rien n'est envoyé avant).
    private var promoBanner: some View {
        HStack(spacing: 8) {
            Spacer()
            Text("Envie de corriger ces points ? HPI Innovations est disponible.")
                .font(.system(size: 12))
                .foregroundColor(Theme.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Button {
                model.openPromo()
            } label: {
                Text("hpi-innovations.fr →").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.teal)
            .help("Ouvre le site dans votre navigateur")
            Text("·").font(.system(size: 12)).foregroundColor(Theme.muted)
            Button {
                model.openPromoMail()
            } label: {
                Text(verbatim: "damien@hpi-innovations.fr").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.teal)
            .help("Ouvre un nouveau message dans votre application de mail")
            Spacer()
            Button {
                model.promoDismissed = true
            } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.muted)
            .help("Masquer ce bandeau")
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Theme.teal.opacity(0.08))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: Accueil

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
            Text("« Une page » analyse l'adresse donnée. « Tout le site » lit le sitemap et classe les pages de la plus faible à la meilleure.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.navy)
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

    // MARK: Détail d'une page (ou analyse d'une seule page)

    private func results(_ r: Report) -> some View {
        VStack(spacing: 0) {
            if let d = model.detail {
                HStack(spacing: 10) {
                    Button {
                        model.detail = nil
                    } label: {
                        Label("Retour à la liste des pages", systemImage: "chevron.left")
                    }
                    Text(d.path).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.navy)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }

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
                Button(model.detail != nil ? "Exporter cette page…" : "Exporter le rapport…") { model.export() }
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

    // MARK: Tout le site

    fileprivate func siteView(_ s: SiteReport) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                ScoreRing(title: "Score moyen", subtitle: Report.grade(s.globalScore), score: s.globalScore, big: true)
                ForEach(Pillar.allCases) { p in
                    ScoreRing(title: p.rawValue, subtitle: p.subtitle, score: s.score(p))
                }
            }
            .padding(.vertical, 18).padding(.horizontal, 20)

            HStack {
                Picker("", selection: $model.siteTab) {
                    ForEach(SiteTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 560)
                Spacer()
                Button("Exporter le dossier complet…") { model.export() }
                    .help("Crée un dossier : rapport global, un rapport détaillé par page, et deux tableaux CSV (Excel).")
            }
            .padding(.horizontal, 20).padding(.bottom, 6)

            Text("\(s.pages.count) page(s) analysée(s) sur \(s.sitemapTotal) dans le sitemap"
                 + (s.unreachable > 0 ? " · \(s.unreachable) injoignable(s)" : "")
                 + (s.isDemo ? " · mode démo (site fictif)" : ""))
                .font(.caption).foregroundColor(Theme.muted).padding(.bottom, 8)

            if let n = model.exportNotice {
                Text(n).font(.caption).foregroundColor(Theme.ok).padding(.bottom, 6)
            }
            if let e = model.errorMessage {
                Text(e).foregroundColor(Theme.fail).padding(.bottom, 6)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    switch model.siteTab {
                    case .pages: pagesTable(s)
                    case .recurring: recurringList(s)
                    case .linking: linkingView(s)
                    case .backlinks: backlinksView(s)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
    }

    private func scoreCell(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(Theme.score(n))
            .frame(width: 52)
    }

    private func headerCell(_ t: String, width: CGFloat) -> some View {
        Text(t).font(.caption.bold()).foregroundColor(Theme.muted).frame(width: width)
    }

    @ViewBuilder
    private func pagesTable(_ s: SiteReport) -> some View {
        Text("Classées de la plus faible à la meilleure. Cliquez sur une page pour voir son analyse détaillée.")
            .font(.caption).foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: 0) {
            headerCell("Score", width: 62)
            Text("Page").font(.caption.bold()).foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
            headerCell("SEO", width: 52)
            headerCell("GSO", width: 52)
            headerCell("Accès IA", width: 62)
            headerCell("Entrants", width: 56)
            headerCell("À corriger", width: 80)
            Spacer().frame(width: 24)
        }
        .padding(.horizontal, 14)
        ForEach(s.pages) { p in
            Button {
                model.open(p)
            } label: {
                HStack(spacing: 0) {
                    Text("\(p.score)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 30)
                        .background(Theme.score(p.score))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 62, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.path).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.navy).lineLimit(1)
                        Text(p.title).font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    scoreCell(p.report.score(.seo))
                    scoreCell(p.report.score(.gso))
                    Text("\(p.report.score(.ia))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.score(p.report.score(.ia)))
                        .frame(width: 62)
                    Text("\(s.inbound(p))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(s.inbound(p) == 0 && p.key != Analyzer.key(URL(string: s.rootURL)!) ? Theme.fail : Theme.navy)
                        .frame(width: 56)
                    Text("\(p.failCount) pb · \(p.warnCount) à améliorer")
                        .font(.caption2).foregroundColor(Theme.muted)
                        .frame(width: 80)
                    Image(systemName: "chevron.right").foregroundColor(Theme.muted).frame(width: 24)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func recurringList(_ s: SiteReport) -> some View {
        let dups = s.duplicateTitles
        if !dups.isEmpty {
            ForEach(dups) { d in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: Theme.symbol(.warn)).foregroundColor(Theme.warn).font(.title3).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Titre en double sur \(d.paths.count) pages").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.navy)
                        Text("« \(d.title) »").font(.system(size: 13)).foregroundColor(Theme.muted)
                        Text(d.paths.joined(separator: "  ·  ")).font(.system(size: 12)).foregroundColor(Theme.muted)
                        Text("→ Donnez à chaque page un titre unique : Google et les IA ont besoin de les distinguer.")
                            .font(.system(size: 13)).foregroundColor(Theme.navy)
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
        ForEach(s.recurring) { r in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: Theme.symbol(r.status)).foregroundColor(Theme.status(r.status)).font(.title3).frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(r.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.navy)
                        PillarBadge(pillar: r.pillar)
                    }
                    Text("Concerne \(r.count) page(s) sur \(r.total)").font(.system(size: 13)).foregroundColor(Theme.muted)
                    if let a = r.advice { Text("→ \(a)").font(.system(size: 13)).foregroundColor(Theme.navy) }
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
}

struct InfoCard: View {
    let status: Status
    let title: String
    var detail: String?
    var advice: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Theme.symbol(status)).foregroundColor(Theme.status(status)).font(.title3).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.navy)
                if let d = detail { Text(d).font(.system(size: 13)).foregroundColor(Theme.muted) }
                if let a = advice { Text("→ \(a)").font(.system(size: 13)).foregroundColor(Theme.navy) }
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

struct StatTile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06)))
    }
}

struct CountList: View {
    let title: String
    let items: [CountedItem]
    var flagGeneric = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.navy).padding(12)
            ForEach(items.prefix(10)) { it in
                Divider()
                HStack {
                    Text(it.name).font(.system(size: 13)).foregroundColor(Theme.navy).lineLimit(1).truncationMode(.middle)
                    if flagGeneric && isGenericAnchor(it.name) {
                        Text("générique").font(.caption2.bold()).foregroundColor(Theme.warn)
                    }
                    Spacer()
                    Text("\(it.count)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Theme.navy)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06)))
    }
}

extension ContentView {
    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.navy)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
    }

    private func more(_ n: Int, limit: Int = 30) -> some View {
        Group {
            if n > limit {
                Text("… et \(n - limit) autre(s). Le rapport exporté les liste toutes.")
                    .font(.caption).foregroundColor(Theme.muted)
            }
        }
    }

    private func pathString(_ url: String) -> String {
        URL(string: url).map { Analyzer.pathOf($0) } ?? url
    }

    @ViewBuilder
    func linkingView(_ s: SiteReport) -> some View {
        let l = s.linking
        HStack(spacing: 10) {
            StatTile(value: "\(l.broken.count)", label: "liens cassés", color: l.broken.isEmpty ? Theme.ok : Theme.fail)
            StatTile(value: "\(l.orphans.count)", label: l.orphansConfirmed ? "pages orphelines" : "pages sans lien entrant",
                     color: l.orphans.isEmpty ? Theme.ok : Theme.warn)
            StatTile(value: "\(l.maxDepth)", label: "clics max depuis l'accueil", color: l.maxDepth > 3 ? Theme.warn : Theme.ok)
            StatTile(value: "\(l.weakAnchorTotal + l.emptyAnchorCount)", label: "textes de lien faibles",
                     color: l.weakAnchorTotal + l.emptyAnchorCount == 0 ? Theme.ok : Theme.warn)
        }
        Text("\(l.totalLinks) liens internes trouvés dans les pages analysées, vers \(l.distinctTargets) adresses. "
             + "\(l.verifiedTargets) adresse(s) liée(s) mais non analysée(s) vérifiée(s)"
             + (l.notVerified > 0 ? " (\(l.notVerified) non vérifiées : limite de 100)." : "."))
            .font(.caption).foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)

        sectionTitle("Liens cassés")
        if l.broken.isEmpty {
            InfoCard(status: .ok, title: "Aucun lien interne cassé trouvé")
        } else {
            ForEach(l.broken.prefix(30)) { b in
                InfoCard(status: .fail,
                         title: "\(pathString(b.url)) — \(b.status.map { "erreur \($0)" } ?? "injoignable")",
                         detail: b.sources.isEmpty ? "Présente dans le sitemap, mais la page ne répond pas."
                                                   : "Lien trouvé sur : " + b.sources.prefix(5).joined(separator: ", ") + (b.sources.count > 5 ? "…" : ""),
                         advice: "Corrigez le lien, ou redirigez l'ancienne adresse vers une page qui existe.")
            }
            more(l.broken.count)
        }

        sectionTitle(l.orphansConfirmed ? "Pages orphelines (aucun lien interne ne mène vers elles)" : "Pages sans lien entrant (parmi les pages analysées)")
        if l.orphans.isEmpty {
            InfoCard(status: .ok, title: "Toutes les pages analysées reçoivent au moins un lien interne")
        } else {
            ForEach(l.orphans.prefix(30)) { o in
                InfoCard(status: .warn, title: o.path,
                         detail: l.orphansConfirmed ? "Dans le sitemap, mais aucune page analysée ne pointe vers elle."
                                                    : "Aucune des pages analysées ne pointe vers elle (à confirmer en analysant plus de pages).",
                         advice: "Ajoutez un lien depuis une page pertinente, ou retirez-la du sitemap si elle est obsolète.")
            }
            more(l.orphans.count)
        }

        sectionTitle("Liens qui passent par une redirection")
        if l.redirects.isEmpty {
            InfoCard(status: .ok, title: "Aucun lien interne vers une adresse redirigée")
        } else {
            ForEach(l.redirects.prefix(30)) { r in
                InfoCard(status: .warn, title: "\(r.from) → \(r.to)",
                         detail: "Lien trouvé sur : " + r.sources.prefix(5).joined(separator: ", "),
                         advice: "Pointez directement vers l'adresse finale : plus rapide pour les visiteurs et les robots.")
            }
            more(l.redirects.count)
        }

        sectionTitle("Profondeur : pages à plus de 3 clics de l'accueil")
        if l.deep.isEmpty && l.unreachable.isEmpty {
            InfoCard(status: .ok, title: "Toutes les pages analysées sont à 3 clics ou moins de l'accueil")
        }
        ForEach(l.deep.prefix(30)) { d in
            InfoCard(status: .warn, title: "\(d.ref.path) — \(d.depth) clics",
                     advice: "Rapprochez-la de l'accueil : un lien depuis le menu ou une page de catégorie.")
        }
        ForEach(l.unreachable.prefix(30)) { u in
            InfoCard(status: .warn, title: "\(u.path) — non atteignable depuis l'accueil",
                     detail: "Elle reçoit des liens, mais uniquement depuis des pages elles-mêmes inaccessibles par les liens.")
        }

        sectionTitle("Textes des liens")
        if l.weakAnchors.isEmpty && l.emptyAnchorCount == 0 {
            InfoCard(status: .ok, title: "Les liens internes ont des textes descriptifs")
        }
        ForEach(l.weakAnchors.prefix(15)) { w in
            InfoCard(status: .warn, title: "« \(w.text) » — \(w.count) lien(s)",
                     detail: "Par exemple sur : " + w.examples.joined(separator: ", "),
                     advice: "Décrivez la page visée (ex. « Nos escaliers en chêne »).")
        }
        if l.emptyAnchorCount > 0 {
            InfoCard(status: .warn, title: "\(l.emptyAnchorCount) lien(s) sans texte (image sans description, par exemple)",
                     detail: "Par exemple sur : " + l.emptyAnchorSources.prefix(3).joined(separator: ", "),
                     advice: "Ajoutez un texte, ou un attribut alt sur l'image qui sert de lien.")
        }
    }

    @ViewBuilder
    func backlinksView(_ s: SiteReport) -> some View {
        if let b = model.backlinks, !b.isEmpty {
            HStack(spacing: 10) {
                StatTile(value: "\(b.sites.count)", label: "sites référents", color: Theme.navy)
                StatTile(value: "\(b.totalLinks)", label: "liens entrants", color: Theme.navy)
                StatTile(value: "\(b.pages.count)", label: "pages de votre site liées", color: Theme.navy)
            }
            Text((s.isDemo ? "Données fictives de démonstration. " : "")
                 + "Google Search Console ne montre qu'un échantillon des liens (les plus importants) : ces chiffres sont indicatifs.")
                .font(.caption).foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
            if !b.sites.isEmpty { CountList(title: "Sites qui vous font le plus de liens", items: b.sites) }
            if !b.pages.isEmpty { CountList(title: "Pages de votre site les plus liées", items: b.pages) }
            if !b.anchors.isEmpty { CountList(title: "Textes utilisés pour vous citer", items: b.anchors, flagGeneric: true) }
            if !b.pages.isEmpty {
                sectionTitle("Pages analysées sans aucun backlink connu")
                let none = s.pages.filter { b.linkCount(forPageKey: $0.key) == 0 }
                if none.isEmpty {
                    InfoCard(status: .ok, title: "Toutes les pages analysées apparaissent dans l'export")
                } else {
                    ForEach(none.prefix(30)) { p in
                        InfoCard(status: .info, title: p.path, detail: "Absente de l'export (pas de lien externe connu, ou hors de l'échantillon).")
                    }
                    more(none.count)
                }
            }
            if !b.skipped.isEmpty {
                InfoCard(status: .warn, title: "Fichiers ignorés", detail: b.skipped.joined(separator: "\n"))
            }
            HStack {
                Button("Importer d'autres fichiers…") { model.importBacklinks() }
                Button("Retirer les données") { model.clearBacklinks() }
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mesurer vos backlinks").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.navy)
                Text("Les backlinks (liens d'autres sites vers le vôtre) comptent beaucoup pour Google et pour être cité par les IA. Phare ne voit que votre site : il ne peut pas savoir qui vous cite. Google Search Console, gratuit, le sait pour votre propre site.")
                    .font(.system(size: 13)).foregroundColor(Theme.muted)
                Text("1. Dans Google Search Console, ouvrez le rapport « Liens » et la partie « Liens externes ».\n2. Pour chaque tableau (sites référents, pages les plus liées, textes d'ancrage), utilisez « Exporter » puis le format CSV (ou téléchargez le .zip).\n3. Importez ici les fichiers : Phare reconnaît chaque tableau à son contenu.")
                    .font(.system(size: 13)).foregroundColor(Theme.navy)
                Button {
                    model.importBacklinks()
                } label: {
                    Text("Importer l'export Search Console…").padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
                if let b = model.backlinks, !b.skipped.isEmpty {
                    Text("Aucune donnée exploitable. " + b.skipped.joined(separator: " · "))
                        .font(.caption).foregroundColor(Theme.fail)
                }
                Text("Les données restent sur votre Mac. Seuls les liens vers votre propre site sont concernés (l'export « Liens internes » est ignoré).")
                    .font(.caption).foregroundColor(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06)))
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
        .defaultSize(width: 1000, height: 780)
    }
}
