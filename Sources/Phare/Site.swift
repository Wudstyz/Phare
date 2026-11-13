import Foundation

struct PageResult: Identifiable {
    let id = UUID()
    let report: Report

    var url: String { report.finalURL }
    var key: String { URL(string: url).map { Analyzer.key($0) } ?? url }
    var path: String { URL(string: url).map { Analyzer.pathOf($0) } ?? url }
    var score: Int { report.globalScore }
    var title: String { report.facts.first(where: { $0.label == "Titre" })?.value ?? "—" }
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

// MARK: - Audit du maillage interne

struct PageRef: Identifiable {
    let id = UUID()
    let path: String
    let key: String
}

struct DeepPage: Identifiable {
    let id = UUID()
    let ref: PageRef
    let depth: Int
}

struct BrokenLink: Identifiable {
    let id = UUID()
    let url: String
    let status: Int?          // nil = injoignable
    let sources: [String]     // pages où le lien a été trouvé (vide = vient du sitemap)
}

struct RedirectLink: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let sources: [String]
}

struct AnchorIssue: Identifiable {
    let id = UUID()
    let text: String
    let count: Int
    let examples: [String]
}

struct LinkingAudit {
    var totalLinks = 0
    var distinctTargets = 0
    var inbound: [String: Int] = [:]
    var inboundFrom: [String: [String]] = [:]   // page (clé) → pages qui pointent vers elle
    var depth: [String: Int] = [:]              // page (clé) → clics depuis l'accueil
    var orphans: [PageRef] = []
    var orphansConfirmed = false
    var deep: [DeepPage] = []
    var unreachable: [PageRef] = []
    var maxDepth = 0
    var weakAnchors: [AnchorIssue] = []
    var weakAnchorTotal = 0
    var emptyAnchorCount = 0
    var emptyAnchorSources: [String] = []
    var broken: [BrokenLink] = []
    var redirects: [RedirectLink] = []
    var verifiedTargets = 0
    var notVerified = 0

    static func build(reports: [Report], homeKey: String, redirectMap: [String: String], failed: [String: Int],
                      urlByKey: [String: URL], complete: Bool, verified: Int, notVerified: Int) -> LinkingAudit {
        var a = LinkingAudit()
        a.verifiedTargets = verified
        a.notVerified = notVerified
        a.orphansConfirmed = complete

        func canon(_ k: String) -> String { redirectMap[k] ?? k }
        func pathOf(_ k: String) -> String {
            if let u = urlByKey[k] { return Analyzer.pathOf(u) }
            if let i = k.firstIndex(of: "/") { return String(k[i...]) }
            return k
        }

        let analyzed: [(key: String, path: String)] = reports.map { r in
            let u = URL(string: r.finalURL)!
            return (Analyzer.key(u), Analyzer.pathOf(u))
        }
        let analyzedKeys = Set(analyzed.map { $0.key })

        var inboundSources: [String: Set<String>] = [:]
        var adj: [String: Set<String>] = [:]
        var rawSources: [String: Set<String>] = [:]
        var weak: [String: (count: Int, sources: Set<String>)] = [:]
        var emptySources = Set<String>()

        for (i, r) in reports.enumerated() {
            let sk = analyzed[i].key
            let sp = analyzed[i].path
            for l in r.outlinks {
                let raw = Analyzer.key(l.url)
                let t = canon(raw)
                if t == sk { continue }
                a.totalLinks += 1
                rawSources[raw, default: []].insert(sp)
                inboundSources[t, default: []].insert(sp)
                adj[sk, default: []].insert(t)
                let text = l.anchor.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    a.emptyAnchorCount += 1
                    emptySources.insert(sp)
                } else if isGenericAnchor(text) {
                    var e = weak[text.lowercased()] ?? (count: 0, sources: [])
                    e.count += 1
                    e.sources.insert(sp)
                    weak[text.lowercased()] = e
                }
            }
        }
        a.distinctTargets = rawSources.count
        a.inbound = inboundSources.mapValues { $0.count }
        a.inboundFrom = inboundSources.mapValues { $0.sorted() }
        a.emptyAnchorSources = emptySources.sorted()
        a.weakAnchorTotal = weak.values.reduce(0) { $0 + $1.count }
        a.weakAnchors = weak.map { AnchorIssue(text: $0.key, count: $0.value.count, examples: Array($0.value.sources.sorted().prefix(3))) }
            .sorted { $0.count > $1.count }

        // Liens cassés
        var broken: [BrokenLink] = []
        for (raw, st) in failed {
            let src = (rawSources[raw] ?? []).sorted()
            broken.append(BrokenLink(url: urlByKey[raw]?.absoluteString ?? raw, status: st == 0 ? nil : st, sources: src))
        }
        a.broken = broken.sorted {
            if $0.sources.count != $1.sources.count { return $0.sources.count > $1.sources.count }
            return $0.url < $1.url
        }

        // Redirections
        for (raw, to) in redirectMap {
            guard let src = rawSources[raw], !src.isEmpty else { continue }
            a.redirects.append(RedirectLink(from: pathOf(raw), to: pathOf(to), sources: src.sorted()))
        }
        a.redirects.sort { $0.sources.count > $1.sources.count }

        // Pages orphelines
        for p in analyzed where p.key != homeKey && (a.inbound[p.key] ?? 0) == 0 {
            a.orphans.append(PageRef(path: p.path, key: p.key))
        }

        // Profondeur de clics depuis l'accueil
        var depth: [String: Int] = [homeKey: 0]
        var queue = [homeKey]
        var qi = 0
        while qi < queue.count {
            let k = queue[qi]
            qi += 1
            for n in adj[k] ?? [] where analyzedKeys.contains(n) && depth[n] == nil {
                depth[n] = depth[k]! + 1
                queue.append(n)
            }
        }
        a.maxDepth = depth.values.max() ?? 0
        a.depth = depth
        for p in analyzed {
            if let d = depth[p.key] {
                if d > 3 { a.deep.append(DeepPage(ref: PageRef(path: p.path, key: p.key), depth: d)) }
            } else if (a.inbound[p.key] ?? 0) > 0 {
                a.unreachable.append(PageRef(path: p.path, key: p.key))
            }
        }
        a.deep.sort { $0.depth > $1.depth }
        return a
    }
}

// MARK: - Rapport du site

struct SiteReport {
    let rootURL: String
    let date: Date
    let pages: [PageResult]        // déjà triées : pire score en premier
    let sitemapTotal: Int
    let unreachable: Int
    let isDemo: Bool
    let linking: LinkingAudit

    func score(_ p: Pillar) -> Int {
        guard !pages.isEmpty else { return 0 }
        return Int((Double(pages.map { $0.report.score(p) }.reduce(0, +)) / Double(pages.count)).rounded())
    }

    var globalScore: Int {
        guard !pages.isEmpty else { return 0 }
        return Int((Double(pages.map { $0.score }.reduce(0, +)) / Double(pages.count)).rounded())
    }

    func inbound(_ p: PageResult) -> Int { linking.inbound[p.key] ?? 0 }

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

    func markdown(backlinks: BacklinkData? = nil, pageFiles: [UUID: String] = [:]) -> String {
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

        let l = linking
        out += "\n## Maillage interne\n\n"
        out += "- Liens internes trouvés : \(l.totalLinks) (vers \(l.distinctTargets) adresses distinctes) ; profondeur maximale : \(l.maxDepth) clic(s) depuis l'accueil\n"
        out += "- Adresses vérifiées en plus des pages analysées : \(l.verifiedTargets)"
        if l.notVerified > 0 { out += " (\(l.notVerified) non vérifiées : limite de 100)" }
        out += "\n"
        out += "- Liens cassés : \(l.broken.count)\n"
        for b in l.broken { out += "  - \(b.url) — \(b.status.map(String.init) ?? "injoignable")" + (b.sources.isEmpty ? " (présent dans le sitemap)" : " ← \(b.sources.joined(separator: ", "))") + "\n" }
        out += "- Liens passant par une redirection : \(l.redirects.count)\n"
        for r in l.redirects { out += "  - \(r.from) → \(r.to) ← \(r.sources.joined(separator: ", "))\n" }
        out += "- Pages sans lien entrant\(l.orphansConfirmed ? "" : " (parmi les pages analysées, à confirmer)") : \(l.orphans.count)\n"
        for o in l.orphans { out += "  - \(o.path)\n" }
        out += "- Pages à plus de 3 clics de l'accueil : \(l.deep.count)\n"
        for d in l.deep { out += "  - \(d.ref.path) (\(d.depth) clics)\n" }
        out += "- Textes de lien génériques : \(l.weakAnchorTotal) ; vides : \(l.emptyAnchorCount)\n"
        for w in l.weakAnchors.prefix(10) { out += "  - « \(w.text) » × \(w.count)\n" }

        if let b = backlinks, !b.isEmpty {
            out += "\n## Backlinks (import Google Search Console)\n\n"
            out += "- Sites référents : \(b.sites.count) ; liens entrants : \(b.totalLinks)\n"
            for s in b.sites.prefix(10) { out += "  - \(s.name) : \(s.count)\n" }
            if !b.pages.isEmpty {
                out += "- Pages les plus liées :\n"
                for p in b.pages.prefix(10) { out += "  - \(p.name) : \(p.count)\n" }
            }
            if !b.anchors.isEmpty {
                out += "- Textes d'ancrage les plus utilisés :\n"
                for a in b.anchors.prefix(10) { out += "  - « \(a.name) » : \(a.count)\n" }
            }
            if !b.skipped.isEmpty { out += "- Fichiers ignorés : \(b.skipped.joined(separator: " ; "))\n" }
        }

        out += "\n## Pages (de la plus faible à la meilleure)\n\n| Score | SEO | GSO | Accès IA | Liens entrants | Page |\n|---|---|---|---|---|---|\n"
        for p in pages {
            let label = pageFiles[p.id].map { "[\(p.path)](\($0))" } ?? p.path
            out += "| \(p.score) | \(p.report.score(.seo)) | \(p.report.score(.gso)) | \(p.report.score(.ia)) | \(inbound(p)) | \(label) |\n"
        }
        return out
    }
}

// MARK: - Analyse de plusieurs pages

private struct Crawl {
    let requested: URL
    let report: Report?
    let status: Int?
    let finalURL: URL?
}

extension Analyzer {
    static let skippedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "svg", "pdf", "xml", "gz", "zip", "mp4", "mp3", "css", "js", "ico", "xsd", "json", "woff", "woff2", "ttf", "rss", "atom"]

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

    static func pathOf(_ u: URL) -> String {
        var p = u.path.isEmpty ? "/" : u.path
        if let q = u.query { p += "?" + q }
        return p
    }

    static func sample(_ urls: [URL], max: Int) -> [URL] {
        guard max > 0 else { return [] }
        guard urls.count > max else { return urls }
        let step = Double(urls.count) / Double(max)
        return (0..<max).map { urls[Int(Double($0) * step)] }
    }

    /// Analyse la page d'accueil puis un échantillon de pages du sitemap (4 requêtes à la fois, avec une pause),
    /// puis vérifie jusqu'à 100 adresses liées mais non analysées (liens cassés, redirections).
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
        let complete = sampled.count == others.count
        var total = sampled.count + 1
        var crawls: [Crawl] = []
        var done = 1
        await progress(done, total)

        // Phase 1 : pages du sitemap
        var index = 0
        await withTaskGroup(of: Crawl.self) { group in
            func launch() {
                guard index < sampled.count else { return }
                let u = sampled[index]
                index += 1
                group.addTask {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    guard let p = await self.fetch(u) else { return Crawl(requested: u, report: nil, status: nil, finalURL: nil) }
                    if p.status >= 400 { return Crawl(requested: u, report: nil, status: p.status, finalURL: p.finalURL) }
                    return Crawl(requested: u, report: self.analyzePage(p, files: files, input: u.absoluteString), status: p.status, finalURL: p.finalURL)
                }
            }
            for _ in 0..<4 { launch() }
            while let c = await group.next() {
                done += 1
                crawls.append(c)
                await progress(done, total)
                launch()
            }
        }

        let reports = [homeReport] + crawls.compactMap { $0.report }
        var redirectMap: [String: String] = [:]
        var failed: [String: Int] = [:]
        let homeRequestedKey = Analyzer.key(url)
        if homeRequestedKey != homeKey { redirectMap[homeRequestedKey] = homeKey }
        for c in crawls {
            let rk = Analyzer.key(c.requested)
            if c.report != nil, let f = c.finalURL {
                let fk = Analyzer.key(f)
                if fk != rk { redirectMap[rk] = fk }
            } else {
                failed[rk] = c.status ?? 0
            }
        }
        let unreachable = crawls.filter { $0.report == nil }.count

        // Phase 2 : adresses liées mais non analysées
        var rawSources: [String: Set<String>] = [:]
        var urlByKey: [String: URL] = [:]
        for r in reports {
            let sp = URL(string: r.finalURL).map { Analyzer.pathOf($0) } ?? r.finalURL
            for l in r.outlinks {
                let k = Analyzer.key(l.url)
                rawSources[k, default: []].insert(sp)
                if urlByKey[k] == nil { urlByKey[k] = l.url }
            }
        }
        for c in crawls { urlByKey[Analyzer.key(c.requested)] = c.requested }
        urlByKey[homeKey] = home.finalURL

        var known = Set(reports.compactMap { URL(string: $0.finalURL) }.map { Analyzer.key($0) })
        known.formUnion(redirectMap.keys)
        known.formUnion(failed.keys)
        let candidates = rawSources.keys
            .filter { k in
                guard !known.contains(k), let u = urlByKey[k] else { return false }
                return !Analyzer.skippedExtensions.contains(u.pathExtension.lowercased())
            }
            .sorted {
                let a = rawSources[$0]!.count, b = rawSources[$1]!.count
                return a != b ? a > b : $0 < $1
            }
        let toCheck = Array(candidates.prefix(100))
        let notVerified = candidates.count - toCheck.count
        total += toCheck.count

        var checkIndex = 0
        await withTaskGroup(of: (String, Int?, String?).self) { group in
            func launch() {
                guard checkIndex < toCheck.count else { return }
                let k = toCheck[checkIndex]
                checkIndex += 1
                let u = urlByKey[k]!
                group.addTask {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    guard let p = await self.fetch(u) else { return (k, nil, nil) }
                    return (k, p.status, Analyzer.key(p.finalURL))
                }
            }
            for _ in 0..<4 { launch() }
            while let (k, status, finalKey) = await group.next() {
                done += 1
                if let s = status {
                    if s >= 400 { failed[k] = s }
                    else if let fk = finalKey, fk != k { redirectMap[k] = fk }
                } else {
                    failed[k] = 0
                }
                await progress(done, total)
                launch()
            }
        }

        let audit = LinkingAudit.build(reports: reports, homeKey: homeKey, redirectMap: redirectMap, failed: failed,
                                       urlByKey: urlByKey, complete: complete, verified: toCheck.count, notVerified: notVerified)

        let pages = reports.map { PageResult(report: $0) }.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.path < $1.path
        }
        return SiteReport(rootURL: home.finalURL.absoluteString, date: Date(), pages: pages,
                          sitemapTotal: others.count + 1, unreachable: unreachable, isDemo: isDemo, linking: audit)
    }
}
