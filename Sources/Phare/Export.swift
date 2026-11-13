import Foundation

extension SiteReport {
    /// Rapport détaillé d'une seule page du site : analyse complète + maillage + backlinks.
    func pageMarkdown(_ page: PageResult, backlinks: BacklinkData?, back: String?) -> String {
        var out = ""
        if let b = back { out += "[← Rapport global du site](\(b))\n\n" }

        let base = page.report.markdown()
        if let r = base.range(of: "# Rapport Phare\n") {
            out += base.replacingCharacters(in: r, with: "# Rapport Phare — \(page.path)\n")
        } else {
            out += base
        }

        let l = linking
        let key = page.key
        let rank = (pages.firstIndex(where: { $0.id == page.id }) ?? 0) + 1

        out += "\n## Place dans le site\n\n"
        out += "- Classement : \(rank)ᵉ page la plus faible sur \(pages.count) analysées (score \(page.score), moyenne du site : \(globalScore))\n"
        if let dup = duplicateTitles.first(where: { $0.paths.contains(page.path) }) {
            let others = dup.paths.filter { $0 != page.path }
            out += "- Titre en double avec : \(others.joined(separator: ", "))\n"
        }

        out += "\n## Maillage de cette page\n\n"
        if let d = l.depth[key] {
            out += "- Profondeur : " + (d == 0 ? "page d'accueil" : "\(d) clic(s) depuis l'accueil") + "\n"
        } else {
            out += "- Profondeur : non atteignable depuis l'accueil parmi les pages analysées\n"
        }
        let from = l.inboundFrom[key] ?? []
        out += "- Liens internes entrants : \(from.count)"
        if from.isEmpty && key != Analyzer.key(URL(string: rootURL)!) {
            out += l.orphansConfirmed ? " — **page orpheline**" : " — aucun lien depuis les pages analysées (à confirmer)"
        }
        out += "\n"
        for f in from.prefix(50) { out += "  - \(f)\n" }
        if from.count > 50 { out += "  - … et \(from.count - 50) autre(s)\n" }

        // Liens sortants (uniques par adresse + texte)
        var brokenByKey: [String: BrokenLink] = [:]
        for b in l.broken { if let u = URL(string: b.url) { brokenByKey[Analyzer.key(u)] = b } }
        var redirectByPath: [String: RedirectLink] = [:]
        for r in l.redirects { redirectByPath[r.from] = r }

        var seen = Set<String>()
        var rows: [String] = []
        var brokenCount = 0, redirectCount = 0, weakCount = 0
        for o in page.report.outlinks {
            let k = Analyzer.key(o.url)
            guard seen.insert(k + "|" + o.anchor).inserted else { continue }
            let target = Analyzer.pathOf(o.url)
            let text = o.anchor.trimmingCharacters(in: .whitespacesAndNewlines)
            var flags: [String] = []
            if let b = brokenByKey[k] { flags.append("LIEN CASSÉ (\(b.status.map { "erreur \($0)" } ?? "injoignable"))"); brokenCount += 1 }
            if let r = redirectByPath[target] { flags.append("redirigé vers \(r.to)"); redirectCount += 1 }
            if text.isEmpty { flags.append("texte vide"); weakCount += 1 }
            else if isGenericAnchor(text) { flags.append("texte générique"); weakCount += 1 }
            if o.nofollow { flags.append("nofollow") }
            rows.append("  - « \(text.isEmpty ? "—" : text) » → \(target)" + (flags.isEmpty ? "" : "  ⚠ " + flags.joined(separator: " ; ")))
        }
        out += "- Liens internes sortants : \(rows.count) (dont \(brokenCount) cassé(s), \(redirectCount) via redirection, \(weakCount) avec un texte faible)\n"
        for r in rows.prefix(100) { out += r + "\n" }
        if rows.count > 100 { out += "  - … et \(rows.count - 100) autre(s)\n" }

        if let b = backlinks, !b.pages.isEmpty {
            let n = b.linkCount(forPageKey: key)
            out += "\n## Backlinks (import Google Search Console)\n\n"
            out += n > 0 ? "- Liens externes connus vers cette page : \(n)\n"
                         : "- Aucun lien externe connu vers cette page dans l'export (ou hors de l'échantillon Search Console)\n"
        }
        return out
    }
}

enum SiteExporter {
    static func slug(_ path: String) -> String {
        if path == "/" { return "accueil" }
        let folded = path.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
        var s = String(folded.map { $0.isLetter || $0.isNumber ? $0 : "-" })
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        s = String(s.prefix(60)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? "page" : s
    }

    /// Nom de fichier de chaque page, dans l'ordre du tableau (la plus faible en premier).
    static func fileNames(for site: SiteReport) -> [UUID: String] {
        var out: [UUID: String] = [:]
        let width = max(2, String(site.pages.count).count)
        for (i, p) in site.pages.enumerated() {
            let num = String(i + 1).leftPad(width)
            out[p.id] = "pages/\(num)-\(slug(p.path)).md"
        }
        return out
    }

    private static func esc(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ") + "\""
    }

    /// CSV lisible par Excel (UTF-8 avec BOM, séparateur « ; »).
    static func pagesCSV(_ site: SiteReport, files: [UUID: String]) -> String {
        var out = "\u{FEFF}Rang;Page;Titre;Score;SEO;GSO;Accès IA;Liens entrants;Clics depuis l'accueil;Problèmes;À améliorer;Fichier détaillé\n"
        for (i, p) in site.pages.enumerated() {
            let depth = site.linking.depth[p.key].map(String.init) ?? "non atteignable"
            out += [String(i + 1), esc(p.path), esc(p.title), String(p.score), String(p.report.score(.seo)), String(p.report.score(.gso)),
                    String(p.report.score(.ia)), String(site.inbound(p)), depth, String(p.failCount), String(p.warnCount),
                    esc(files[p.id] ?? "")].joined(separator: ";") + "\n"
        }
        return out
    }

    /// Une ligne par problème et par page : pratique pour filtrer et trier dans Excel.
    static func issuesCSV(_ site: SiteReport) -> String {
        var out = "\u{FEFF}Page;Pilier;Contrôle;Statut;Détail;Conseil\n"
        for p in site.pages {
            for c in p.report.priorities {
                out += [esc(p.path), esc(c.pillar.rawValue), esc(c.title), esc(c.status.label), esc(c.detail), esc(c.advice ?? "")].joined(separator: ";") + "\n"
            }
        }
        return out
    }

    static func readme(_ site: SiteReport) -> String {
        """
        # Export Phare — \(URL(string: site.rootURL)?.host ?? site.rootURL)

        - `00-rapport-global.md` : synthèse du site (scores moyens, problèmes récurrents, maillage, backlinks, tableau des pages avec liens vers les rapports détaillés).
        - `pages/` : un rapport détaillé par page (analyse SEO / GSO / Accès IA complète, priorités, fiche technique, maillage de la page). Numérotés de la page la plus faible à la meilleure.
        - `pages.csv` : une ligne par page (scores, liens entrants, profondeur, nombre de problèmes). S'ouvre dans Excel ou Numbers.
        - `problemes-par-page.csv` : une ligne par problème et par page, avec le conseil. Pratique pour filtrer et répartir le travail.

        Les fichiers `.md` sont du texte : ouvrez-les avec n'importe quel éditeur ou lecteur Markdown.
        """
    }

    /// Crée un dossier « Phare - site - date » dans `parent` et y écrit tout. Renvoie le dossier créé.
    static func write(site: SiteReport, backlinks: BacklinkData?, into parent: URL) throws -> URL {
        let fm = FileManager.default
        let host = URL(string: site.rootURL)?.host ?? "site"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let base = "Phare - \(host) - \(df.string(from: site.date))"
        var dir = parent.appendingPathComponent(base)
        var n = 2
        while fm.fileExists(atPath: dir.path) {
            dir = parent.appendingPathComponent("\(base) (\(n))")
            n += 1
        }
        try fm.createDirectory(at: dir.appendingPathComponent("pages"), withIntermediateDirectories: true)

        let files = fileNames(for: site)
        func put(_ text: String, _ rel: String) throws {
            try text.write(to: dir.appendingPathComponent(rel), atomically: true, encoding: .utf8)
        }
        try put(site.markdown(backlinks: backlinks, pageFiles: files), "00-rapport-global.md")
        for p in site.pages {
            try put(site.pageMarkdown(p, backlinks: backlinks, back: "../00-rapport-global.md"), files[p.id]!)
        }
        try put(pagesCSV(site, files: files), "pages.csv")
        try put(issuesCSV(site), "problemes-par-page.csv")
        try put(readme(site), "LISEZ-MOI.md")
        return dir
    }
}

private extension String {
    func leftPad(_ width: Int) -> String {
        count >= width ? self : String(repeating: "0", count: width - count) + self
    }
}
