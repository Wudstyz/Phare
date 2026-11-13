import Foundation

struct PageResult: Identifiable {
    let id = UUID()
    let report: Report

    var url: String { report.finalURL }
    var path: String {
        guard let u = URL(string: url) else { return url }
        var p = u.path.isEmpty ? "/" : u.path
        if let q = u.query { p += "?" + q }
        return p
    }
    var score: Int { report.globalScore }
    var title: String {
        let t = report.facts.first(where: { $0.label == "Titre" })?.value ?? "—"
        return t
    }
    var failCount: Int { report.checks.filter { $0.status == .fail }.count }
    var warnCount: Int { report.checks.filter { $0.status == .warn }.count }
}

struct Recurring: Identifiable {
    let id = UUID()
    let pillar: Pillar
    let title: String
    let status: Status
    let count: Int
    let total: Int
    let advice: String?
}

struct DuplicateTitle: Identifiable {
    let id = UUID()
    let title: String
    let paths: [String]
}

struct SiteReport {
    let rootURL: String
    let date: Date
    let pages: [PageResult]        // déjà triées : pire score en premier
    let sitemapTotal: Int
    let unreachable: Int
    let isDemo: Bool

    func score(_ p: Pillar) -> Int {
        guard !pages.isEmpty else { return 0 }
        return Int((Double(pages.map { $0.report.score(p) }.reduce(0, +)) / Double(pages.count)).rounded())
    }

    var globalScore: Int {
        guard !pages.isEmpty else { return 0 }
        return Int((Double(pages.map { $0.score }.reduce(0, +)) / Double(pages.count)).rounded())
    }

    var recurring: [Recurring] {
        struct Acc { var pillar: Pillar; var title: String; var fail = 0; var warn = 0; var advice: String? }
        var map: [String: Acc] = [:]
        for page in pages {
            for c in page.report.checks where c.status == .fail || c.status == .warn {
                let key = c.pillar.rawValue + "|" + c.title
                var a = map[key] ?? Acc(pillar: c.pillar, title: c.title, advice: c.advice)
                if c.status == .fail { a.fail += 1 } else { a.warn += 1 }
                map[key] = a
            }
        }
        return map.values
            .map { Recurring(pillar: $0.pillar, title: $0.title, status: $0.fail > 0 ? .fail : .warn,
                             count: $0.fail + $0.warn, total: pages.count, advice: $0.advice) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.status != $1.status { return $0.status == .fail }
                return $0.title < $1.title
            }
    }

    var duplicateTitles: [DuplicateTitle] {
        var map: [String: [String]] = [:]
        for p in pages where p.title != "—" { map[p.title, default: []].append(p.path) }
        return map.filter { $0.value.count > 1 }
            .map { DuplicateTitle(title: $0.key, paths: $0.value.sorted()) }
            .sorted { $0.paths.count > $1.paths.count }
    }

    func markdown() -> String {
        var out = "# Rapport Phare — site entier\n\n"
        out += "- Site : \(rootURL)\n"
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .short
        out += "- Date : \(f.string(from: date))\n"
        out += "- Pages analysées : \(pages.count) sur \(sitemapTotal) dans le sitemap"
        if unreachable > 0 { out += " (\(unreachable) injoignable(s))" }
        out += "\n"
        if isDemo { out += "- Mode démo (site fictif, aucun accès réseau)\n" }
        out += "\n## Scores moyens\n\n- Global : \(globalScore)/100 (\(Report.grade(globalScore)))\n"
        for p in Pillar.allCases { out += "- \(p.rawValue) : \(score(p))/100\n" }
        if !duplicateTitles.isEmpty {
            out += "\n## Titres en double\n\n"
            for d in duplicateTitles { out += "- « \(d.title) » : \(d.paths.joined(separator: ", "))\n" }
        }
        out += "\n## Problèmes récurrents\n\n"
        for r in recurring.prefix(20) {
            out += "- **[\(r.pillar.rawValue)] \(r.title)** (\(r.status.label)) — \(r.count)/\(r.total) pages"
            if let a = r.advice { out += " → \(a)" }
            out += "\n"
        }
        out += "\n## Pages (de la plus faible à la meilleure)\n\n| Score | SEO | GSO | Accès IA | Page |\n|---|---|---|---|---|\n"
        for p in pages {
            out += "| \(p.score) | \(p.report.score(.seo)) | \(p.report.score(.gso)) | \(p.report.score(.ia)) | \(p.path) |\n"
        }
        return out
    }
}

extension Analyzer {
    static let skippedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "svg", "pdf", "xml", "gz", "zip", "mp4", "mp3", "css", "js", "ico"]

    static func locs(in xml: String) -> [String] {
        regexMatches(#"<loc>\s*(?:<!\[CDATA\[)?\s*(.*?)\s*(?:\]\]>)?\s*</loc>"#, in: xml, group: 1).map(decodeEntities)
    }

    /// Lit le sitemap (et ses sous-sitemaps) et renvoie les adresses de pages du même site.
    func sitemapPages(files: SiteFiles, host: String) async -> [URL] {
        let bare = host.lowercased().replacingOccurrences(of: "www.", with: "")
        var bodies = files.sitemapBodies
        if bodies.isEmpty {
            for u in files.sitemapURLs.prefix(3) {
                if let f = await fetch(u), f.status == 200 { bodies.append(f.body) }
            }
        }
        var pages: [URL] = []
        var seen = Set<String>()
        var queue = bodies
        var children = 0
        while !queue.isEmpty, pages.count < 10_000 {
            let body = queue.removeFirst()
            let entries = Analyzer.locs(in: body)
            if body.lowercased().contains("<sitemapindex") {
                for e in entries where children < 15 {
                    guard let u = URL(string: e), !e.lowercased().hasSuffix(".gz") else { continue }
                    children += 1
                    if let f = await fetch(u), f.status == 200 { queue.append(f.body) }
                }
            } else {
                for e in entries {
                    guard let u = URL(string: e), let h = u.host,
                          h.lowercased().replacingOccurrences(of: "www.", with: "") == bare,
                          !Analyzer.skippedExtensions.contains(u.pathExtension.lowercased()) else { continue }
                    if seen.insert(Analyzer.key(u)).inserted { pages.append(u) }
                }
            }
        }
        return pages
    }

    static func key(_ u: URL) -> String {
        var p = u.path.isEmpty ? "/" : u.path
        if p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return (u.host ?? "").lowercased().replacingOccurrences(of: "www.", with: "") + p + (u.query.map { "?" + $0 } ?? "")
    }

    static func sample(_ urls: [URL], max: Int) -> [URL] {
        guard max > 0 else { return [] }
        guard urls.count > max else { return urls }
        let step = Double(urls.count) / Double(max)
        return (0..<max).map { urls[Int(Double($0) * step)] }
    }

    /// Analyse la page d'accueil puis un échantillon de pages du sitemap (4 requêtes à la fois, avec une pause).
    func runSite(_ input: String, maxPages: Int, progress: @escaping @MainActor (Int, Int) -> Void) async throws -> SiteReport {
        guard let url = Analyzer.normalize(input) else { throw AnalyzerError.invalidURL }
        guard let home = await fetch(url) else { throw AnalyzerError.unreachable }
        let files = await loadSiteFiles(for: home.finalURL)
        let homeReport = analyzePage(home, files: files, input: input)

        let all = await sitemapPages(files: files, host: home.finalURL.host ?? "")
        let homeKey = Analyzer.key(home.finalURL)
        let others = all.filter { Analyzer.key($0) != homeKey }
        guard !others.isEmpty else { throw AnalyzerError.noSitemap }

        let sampled = Analyzer.sample(others, max: max(maxPages - 1, 0))
        let total = sampled.count + 1
        var reports: [Report] = [homeReport]
        var done = 1
        var unreachable = 0
        await progress(done, total)

        var index = 0
        await withTaskGroup(of: Report?.self) { group in
            func launch() {
                guard index < sampled.count else { return }
                let u = sampled[index]
                index += 1
                group.addTask {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    guard let p = await self.fetch(u), p.status < 400 else { return nil }
                    return self.analyzePage(p, files: files, input: u.absoluteString)
                }
            }
            for _ in 0..<4 { launch() }
            while let r = await group.next() {
                done += 1
                if let r = r { reports.append(r) } else { unreachable += 1 }
                await progress(done, total)
                launch()
            }
        }

        let pages = reports.map { PageResult(report: $0) }.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.path < $1.path
        }
        return SiteReport(rootURL: home.finalURL.absoluteString, date: Date(), pages: pages,
                          sitemapTotal: others.count + 1, unreachable: unreachable, isDemo: isDemo)
    }
}
