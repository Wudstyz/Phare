import Foundation

struct Fetched {
    var status: Int
    var headers: [String: String]
    var body: String
    var finalURL: URL
    var seconds: Double
    var bytes: Int
}

typealias FetchFn = (URL) async -> Fetched?

enum AnalyzerError: LocalizedError {
    case invalidURL
    case unreachable
    case noSitemap

    var errorDescription: String? {
        switch self {
        case .noSitemap: return "Aucun sitemap exploitable trouvé sur ce site. Utilisez le mode « Une page », ou ajoutez un sitemap.xml."
        case .invalidURL: return "Adresse invalide. Exemple : https://www.monsite.fr"
        case .unreachable: return "Impossible de joindre ce site (adresse erronée, site hors ligne ou pas de connexion Internet)."
        }
    }
}

func liveFetch(_ url: URL) async -> Fetched? {
    var req = URLRequest(url: url)
    req.timeoutInterval = 20
    req.setValue("Mozilla/5.0 (compatible; PhareBot/1.0)", forHTTPHeaderField: "User-Agent")
    req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
    req.setValue("fr-FR,fr;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
    let t0 = Date()
    do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let h = resp as? HTTPURLResponse else { return nil }
        var headers: [String: String] = [:]
        for (k, v) in h.allHeaderFields { headers["\(k)".lowercased()] = "\(v)" }
        let body = String(decoding: data.prefix(3_000_000), as: UTF8.self)
        return Fetched(status: h.statusCode, headers: headers, body: body,
                       finalURL: h.url ?? url, seconds: Date().timeIntervalSince(t0), bytes: data.count)
    } catch {
        return nil
    }
}

struct Bot {
    enum Kind { case search, assistant, training }
    let token: String
    let owner: String
    let kind: Kind
}

let aiBots: [Bot] = [
    Bot(token: "OAI-SearchBot", owner: "OpenAI (recherche ChatGPT)", kind: .search),
    Bot(token: "ChatGPT-User", owner: "OpenAI (ChatGPT qui consulte une page)", kind: .assistant),
    Bot(token: "GPTBot", owner: "OpenAI (entraînement des modèles)", kind: .training),
    Bot(token: "Claude-SearchBot", owner: "Anthropic (recherche Claude)", kind: .search),
    Bot(token: "Claude-User", owner: "Anthropic (Claude qui consulte une page)", kind: .assistant),
    Bot(token: "ClaudeBot", owner: "Anthropic (entraînement des modèles)", kind: .training),
    Bot(token: "PerplexityBot", owner: "Perplexity (recherche)", kind: .search),
    Bot(token: "Perplexity-User", owner: "Perplexity (consultation à la demande)", kind: .assistant),
    Bot(token: "Google-Extended", owner: "Google (entraînement Gemini)", kind: .training),
    Bot(token: "Applebot-Extended", owner: "Apple (entraînement Apple Intelligence)", kind: .training),
    Bot(token: "CCBot", owner: "Common Crawl (base utilisée par de nombreuses IA)", kind: .training),
    Bot(token: "Bytespider", owner: "ByteDance (entraînement)", kind: .training),
    Bot(token: "meta-externalagent", owner: "Meta (entraînement)", kind: .training),
]

struct Analyzer {
    let fetch: FetchFn
    let isDemo: Bool

    static func normalize(_ input: String) -> URL? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(" ") else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") { s = "https://" + s }
        guard let u = URL(string: s), let host = u.host, host.contains(".") else { return nil }
        return u
    }

    /// Fichiers communs à tout le site (robots.txt, llms.txt, sitemap).
    struct SiteFiles {
        var robots: Robots?
        var llmsOK = false
        var sitemapOK = false
        var sitemapBodies: [String] = []   // contenus XML déjà téléchargés
        var sitemapURLs: [URL] = []        // adresses à essayer, dans l'ordre
    }

    func loadSiteFiles(for finalURL: URL) async -> SiteFiles {
        let origin = URL(string: "/", relativeTo: finalURL)!.absoluteURL
        let robotsURL = URL(string: "/robots.txt", relativeTo: origin)!.absoluteURL
        let llmsURL = URL(string: "/llms.txt", relativeTo: origin)!.absoluteURL
        let defaultSitemap = URL(string: "/sitemap.xml", relativeTo: origin)!.absoluteURL
        async let robotsF = fetch(robotsURL)
        async let llmsF = fetch(llmsURL)
        async let sitemapF = fetch(defaultSitemap)
        let robotsRes = await robotsF
        let llmsRes = await llmsF
        let sitemapRes = await sitemapF

        var files = SiteFiles()
        if let r = robotsRes, r.status == 200, !r.body.lowercased().contains("<html") { files.robots = Robots(r.body) }
        if let l = llmsRes, l.status == 200, !l.body.lowercased().contains("<html"), l.body.count > 20 { files.llmsOK = true }
        func looksLikeSitemap(_ f: Fetched?) -> Bool {
            guard let f = f, f.status == 200 else { return false }
            let b = f.body.lowercased()
            return b.contains("<urlset") || b.contains("<sitemapindex")
        }
        let declared = (files.robots?.sitemaps ?? []).compactMap { URL(string: $0) }
        files.sitemapOK = looksLikeSitemap(sitemapRes) || !declared.isEmpty
        files.sitemapURLs = declared.isEmpty ? [defaultSitemap] : declared
        if looksLikeSitemap(sitemapRes), let b = sitemapRes?.body, declared.isEmpty { files.sitemapBodies = [b] }
        return files
    }

    func run(_ input: String) async throws -> Report {
        guard let url = Analyzer.normalize(input) else { throw AnalyzerError.invalidURL }
        guard let page = await fetch(url) else { throw AnalyzerError.unreachable }
        let files = await loadSiteFiles(for: page.finalURL)
        return analyzePage(page, files: files, input: input)
    }

    func analyzePage(_ page: Fetched, files: SiteFiles, input: String) -> Report {
        let host = page.finalURL.host ?? ""
        let doc = HTMLDoc(page.body, host: host, base: page.finalURL)
        let robots = files.robots
        let llmsOK = files.llmsOK
        let sitemapOK = files.sitemapOK
        let pagePath = page.finalURL.path.isEmpty ? "/" : page.finalURL.path

        var checks: [Check] = []
        func add(_ p: Pillar, _ t: String, _ s: Status, _ d: String, _ a: String? = nil, w: Int = 2) {
            checks.append(Check(pillar: p, title: t, status: s, detail: d, advice: a, weight: w))
        }

        // ---------- SEO ----------
        let isHTTPS = page.finalURL.scheme == "https"
        add(.seo, "Connexion sécurisée (HTTPS)", isHTTPS ? .ok : .fail,
            isHTTPS ? "Le site est servi en HTTPS." : "Le site est servi en HTTP non sécurisé.",
            isHTTPS ? nil : "Installez un certificat HTTPS (souvent gratuit chez l'hébergeur) et redirigez tout le trafic dessus.", w: 3)

        add(.seo, "Page accessible", page.status == 200 ? .ok : (page.status < 400 ? .warn : .fail),
            "Code de réponse du serveur : \(page.status).",
            page.status == 200 ? nil : "La page d'accueil devrait répondre 200 sans redirection en chaîne.", w: 3)

        let tl = doc.title.count
        if tl == 0 {
            add(.seo, "Balise title", .fail, "Aucune balise <title>.", "Ajoutez un titre de 30 à 60 caractères contenant votre sujet principal.", w: 4)
        } else if tl < 30 || tl > 60 {
            add(.seo, "Balise title", .warn, "« \(doc.title) » : \(tl) caractères (idéal : 30 à 60).",
                tl > 60 ? "Raccourcissez le titre, Google le tronquera." : "Allongez le titre avec votre sujet et votre lieu ou votre marque.", w: 4)
        } else {
            add(.seo, "Balise title", .ok, "« \(doc.title) » : \(tl) caractères.", w: 4)
        }

        let dl = doc.metaDescription.count
        if dl == 0 {
            add(.seo, "Meta description", .fail, "Aucune meta description.", "Rédigez 70 à 160 caractères qui donnent envie de cliquer et résument la page.", w: 3)
        } else if dl < 70 || dl > 160 {
            add(.seo, "Meta description", .warn, "\(dl) caractères (idéal : 70 à 160).", "Ajustez la longueur pour qu'elle ne soit pas coupée dans les résultats.", w: 3)
        } else {
            add(.seo, "Meta description", .ok, "\(dl) caractères.", w: 3)
        }

        switch doc.h1s.count {
        case 1: add(.seo, "Titre principal (H1)", .ok, "Un seul H1 : « \(doc.h1s[0]) ».", w: 3)
        case 0: add(.seo, "Titre principal (H1)", .fail, "Aucun H1 sur la page.", "Ajoutez un unique H1 décrivant clairement le sujet de la page.", w: 3)
        default: add(.seo, "Titre principal (H1)", .warn, "\(doc.h1s.count) balises H1 trouvées.", "Gardez un seul H1 et passez les autres en H2.", w: 3)
        }

        add(.seo, "Sous-titres (H2/H3)", doc.h2Count >= 2 ? .ok : (doc.h2Count == 1 ? .warn : .fail),
            "\(doc.h2Count) H2 et \(doc.h3Count) H3.",
            doc.h2Count >= 2 ? nil : "Découpez le contenu avec des H2 explicites : utile aux lecteurs, à Google et aux IA.", w: 2)

        add(.seo, "URL canonique", doc.canonical.isEmpty ? .warn : .ok,
            doc.canonical.isEmpty ? "Pas de balise canonical." : "Canonical : \(doc.canonical)",
            doc.canonical.isEmpty ? "Ajoutez <link rel=\"canonical\"> pour éviter les contenus dupliqués." : nil, w: 2)

        let headerRobots = (page.headers["x-robots-tag"] ?? "").lowercased()
        let noindex = doc.robotsMeta.contains("noindex") || headerRobots.contains("noindex")
        add(.seo, "Indexation autorisée", noindex ? .fail : .ok,
            noindex ? "La page demande à ne PAS être indexée (noindex)." : "Aucun blocage d'indexation détecté.",
            noindex ? "Retirez noindex si vous voulez apparaître sur Google." : nil, w: 5)

        add(.seo, "Affichage mobile (viewport)", doc.viewport.isEmpty ? .fail : .ok,
            doc.viewport.isEmpty ? "Pas de balise viewport." : "Balise viewport présente.",
            doc.viewport.isEmpty ? "Ajoutez <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">." : nil, w: 3)

        add(.seo, "Langue de la page", doc.lang.isEmpty ? .warn : .ok,
            doc.lang.isEmpty ? "Attribut lang absent." : "Langue déclarée : \(doc.lang).",
            doc.lang.isEmpty ? "Ajoutez lang=\"fr\" sur la balise <html>." : nil, w: 1)

        if doc.imagesTotal == 0 {
            add(.seo, "Textes alternatifs des images", .info, "Aucune image détectée dans le HTML.", w: 2)
        } else {
            let miss = doc.imagesMissingAlt
            let st: Status = miss == 0 ? .ok : (Double(miss) / Double(doc.imagesTotal) > 0.3 ? .fail : .warn)
            add(.seo, "Textes alternatifs des images", st, "\(miss) image(s) sur \(doc.imagesTotal) sans texte alternatif.",
                miss == 0 ? nil : "Décrivez chaque image utile avec l'attribut alt.", w: 2)
        }

        let ogCount = [doc.ogTitle, doc.ogDescription, doc.ogImage].filter { $0 }.count
        add(.seo, "Aperçu de partage (Open Graph)", ogCount == 3 ? .ok : (ogCount > 0 ? .warn : .fail),
            "\(ogCount)/3 balises présentes (titre, description, image).",
            ogCount == 3 ? nil : "Ajoutez og:title, og:description et og:image pour de beaux aperçus sur les réseaux et messageries.", w: 2)

        add(.seo, "Maillage interne", doc.internalLinks >= 5 ? .ok : (doc.internalLinks >= 2 ? .warn : .fail),
            "\(doc.internalLinks) lien(s) interne(s), \(doc.externalLinks) externe(s).",
            doc.internalLinks >= 5 ? nil : "Reliez cette page à vos autres pages importantes.", w: 2)

        let weakAnchors = doc.outlinks.filter { isGenericAnchor($0.anchor) || $0.anchor.trimmingCharacters(in: .whitespaces).isEmpty }.count
        if doc.outlinks.isEmpty {
            add(.seo, "Textes des liens internes", .info, "Aucun lien interne à évaluer.", w: 2)
        } else {
            let ratio = Double(weakAnchors) / Double(doc.outlinks.count)
            add(.seo, "Textes des liens internes", weakAnchors == 0 ? .ok : (ratio > 0.3 ? .fail : .warn),
                weakAnchors == 0 ? "Les liens internes ont des textes descriptifs."
                                 : "\(weakAnchors) lien(s) sur \(doc.outlinks.count) avec un texte vide ou générique (« cliquez ici », « en savoir plus »…).",
                weakAnchors == 0 ? nil : "Remplacez-les par des textes qui décrivent la page visée : utile à Google et aux IA.", w: 2)
        }

        add(.seo, "Quantité de contenu", doc.words >= 300 ? .ok : (doc.words >= 120 ? .warn : .fail),
            "Environ \(doc.words) mots de texte visible.",
            doc.words >= 300 ? nil : "Les pages riches (300 mots et plus) se positionnent mieux et sont plus citées.", w: 3)

        let speed: Status = page.seconds < 1.5 ? .ok : (page.seconds < 3 ? .warn : .fail)
        add(.seo, "Vitesse de réponse", speed, String(format: "Page reçue en %.2f s.", page.seconds),
            speed == .ok ? nil : "Activez le cache, la compression et un hébergement plus rapide.", w: 3)

        let kb = Double(page.bytes) / 1024
        add(.seo, "Poids du HTML", kb < 200 ? .ok : (kb < 500 ? .warn : .fail), String(format: "%.0f Ko.", kb),
            kb < 200 ? nil : "Allégez le HTML (scripts inline, données inutiles).", w: 1)

        add(.seo, "Fichier robots.txt", robots != nil ? .ok : .warn,
            robots != nil ? "robots.txt trouvé." : "Pas de robots.txt valide.",
            robots != nil ? nil : "Créez /robots.txt pour guider les robots et déclarer votre sitemap.", w: 2)

        add(.seo, "Plan du site (sitemap)", sitemapOK ? .ok : .warn,
            sitemapOK ? "Sitemap détecté." : "Aucun sitemap trouvé.",
            sitemapOK ? nil : "Générez /sitemap.xml et déclarez-le dans robots.txt.", w: 3)

        add(.seo, "Icône du site (favicon)", doc.hasFavicon ? .ok : .info,
            doc.hasFavicon ? "Favicon déclaré." : "Aucun favicon déclaré dans le HTML.", w: 1)

        add(.seo, "Liens entrants (backlinks)", .info,
            "Non mesurés ici : Phare ne voit que votre site, pas les autres sites qui pointent vers lui.",
            "Les backlinks comptent beaucoup pour Google et pour être cité par les IA. Mesurez-les avec Google Search Console (rapport « Liens », import possible dans l'onglet Backlinks du mode « Tout le site ») et gagnez-en : annuaires sérieux, partenaires, presse locale, contenus utiles qu'on a envie de citer.", w: 1)

        // ---------- GSO ----------
        add(.gso, "Données structurées (JSON-LD)", doc.jsonLDBlocks > 0 ? .ok : .fail,
            doc.jsonLDBlocks > 0 ? "\(doc.jsonLDBlocks) bloc(s) JSON-LD." : "Aucune donnée structurée.",
            doc.jsonLDBlocks > 0 ? nil : "Ajoutez du JSON-LD schema.org : les moteurs IA comprennent mieux qui vous êtes et ce que vous proposez.", w: 5)

        let useful: Set<String> = ["Organization", "LocalBusiness", "Article", "BlogPosting", "FAQPage", "Product", "Service", "HowTo", "WebSite", "Person", "BreadcrumbList", "HomeAndConstructionBusiness", "Store"]
        let found = doc.schemaTypes.intersection(useful)
        add(.gso, "Types de schémas utiles", found.count >= 2 ? .ok : (found.count == 1 ? .warn : .fail),
            found.isEmpty ? "Aucun type pertinent détecté." : "Détectés : \(found.sorted().joined(separator: ", ")).",
            found.count >= 2 ? nil : "Ajoutez Organization, WebSite, FAQPage ou Article selon la page.", w: 3)

        add(.gso, "Identité d'entité (sameAs)", doc.hasSameAs ? .ok : .warn,
            doc.hasSameAs ? "Profils officiels reliés (sameAs)." : "Aucun lien sameAs vers vos profils officiels.",
            doc.hasSameAs ? nil : "Reliez votre marque à ses profils (réseaux, annuaires, Wikipédia) pour que les IA l'identifient sans ambiguïté.", w: 3)

        add(.gso, "Questions / FAQ", doc.questionHeadings >= 2 || doc.schemaTypes.contains("FAQPage") ? .ok : (doc.questionHeadings == 1 ? .warn : .fail),
            "\(doc.questionHeadings) intertitre(s) formulé(s) en question.",
            doc.questionHeadings >= 2 ? nil : "Les IA reprennent volontiers des réponses à des questions précises : ajoutez une FAQ avec de vraies questions de clients.", w: 4)

        let structured = doc.listCount + doc.tableCount
        add(.gso, "Contenu facile à citer (listes, tableaux)", structured >= 2 ? .ok : (structured == 1 ? .warn : .fail),
            "\(doc.listCount) liste(s) et \(doc.tableCount) tableau(x).",
            structured >= 2 ? nil : "Présentez les informations clés en listes et tableaux : plus faciles à extraire.", w: 3)

        let intro = doc.firstParagraphWords
        add(.gso, "Réponse directe en début de page", intro >= 15 && intro <= 70 ? .ok : (intro > 0 ? .warn : .fail),
            intro > 0 ? "Premier paragraphe : \(intro) mots." : "Aucun paragraphe d'introduction détecté.",
            intro >= 15 && intro <= 70 ? nil : "Ouvrez par un paragraphe court (15 à 70 mots) qui répond directement à la question principale.", w: 3)

        add(.gso, "Auteur / expertise (E-E-A-T)", doc.hasAuthor ? .ok : .warn,
            doc.hasAuthor ? "Auteur ou entité identifiée." : "Aucun auteur identifié.",
            doc.hasAuthor ? nil : "Indiquez qui écrit (nom, rôle, expérience) : les IA privilégient les sources identifiables.", w: 3)

        add(.gso, "Date de publication / mise à jour", doc.hasDates ? .ok : .warn,
            doc.hasDates ? "Dates détectées." : "Aucune date lisible par machine.",
            doc.hasDates ? nil : "Ajoutez datePublished / dateModified : la fraîcheur compte pour être cité.", w: 2)

        add(.gso, "Sources et références", doc.externalLinks >= 2 ? .ok : (doc.externalLinks == 1 ? .warn : .info),
            "\(doc.externalLinks) lien(s) externe(s).",
            doc.externalLinks >= 2 ? nil : "Citer des sources fiables renforce la crédibilité aux yeux des IA.", w: 2)

        add(.gso, "Chiffres et preuves", doc.statCount >= 3 ? .ok : (doc.statCount >= 1 ? .warn : .fail),
            "\(doc.statCount) donnée(s) chiffrée(s) repérée(s).",
            doc.statCount >= 3 ? nil : "Ajoutez des chiffres vérifiables (années, nombre de clients, prix) : les IA citent des faits précis.", w: 2)

        add(.gso, "Fichier llms.txt", llmsOK ? .ok : .warn,
            llmsOK ? "/llms.txt présent." : "Pas de /llms.txt.",
            llmsOK ? nil : "Ajoutez /llms.txt : un résumé de votre site et de vos pages clés, destiné aux IA (standard émergent, non garanti).", w: 2)

        // ---------- Accès IA ----------
        for bot in aiBots {
            let allowed = robots?.allowed(agent: bot.token, path: pagePath) ?? true
            switch bot.kind {
            case .search, .assistant:
                add(.ia, bot.token, allowed ? .ok : .fail,
                    allowed ? "Autorisé — \(bot.owner)." : "Bloqué par robots.txt — \(bot.owner).",
                    allowed ? nil : "Si vous voulez apparaître dans les réponses de cette IA, autorisez \(bot.token) dans robots.txt.", w: 3)
            case .training:
                add(.ia, bot.token, .info,
                    allowed ? "Autorisé — \(bot.owner)." : "Bloqué par robots.txt — \(bot.owner). (Choix légitime.)", w: 1)
            }
        }

        let gAllowed = robots?.allowed(agent: "Googlebot", path: pagePath) ?? true
        let bAllowed = robots?.allowed(agent: "Bingbot", path: pagePath) ?? true
        add(.ia, "Googlebot et Bingbot", gAllowed && bAllowed ? .ok : .fail,
            gAllowed && bAllowed ? "Autorisés. Bing alimente plusieurs moteurs IA." : "Un des deux est bloqué : vos pages risquent aussi de disparaître des réponses IA.",
            gAllowed && bAllowed ? nil : "Autorisez Googlebot et Bingbot dans robots.txt.", w: 4)

        let noai = doc.robotsMeta.contains("noai") || headerRobots.contains("noai")
        add(.ia, "Consignes « noai » dans la page", noai ? .warn : .ok,
            noai ? "La page contient une directive noai / noimageai." : "Aucune directive noai.",
            noai ? "Retirez-la si vous voulez que les IA puissent utiliser le contenu." : nil, w: 2)

        let jsHeavy = doc.words < 150 && doc.scriptCount >= 3
        add(.ia, "Contenu lisible sans JavaScript", jsHeavy ? .fail : (doc.words < 150 ? .warn : .ok),
            jsHeavy ? "Peu de texte dans le HTML brut (\(doc.words) mots) et beaucoup de scripts : le contenu est probablement construit par JavaScript."
                    : "\(doc.words) mots présents directement dans le HTML.",
            jsHeavy || doc.words < 150 ? "La plupart des robots IA n'exécutent pas JavaScript : servez le contenu important dans le HTML (rendu serveur)." : nil, w: 4)

        let blockedAll = robots != nil && !(robots!.allowed(agent: "*"))
        add(.ia, "Site fermé à tous les robots", blockedAll ? .fail : .ok,
            blockedAll ? "robots.txt interdit tout le site (Disallow: /)." : "Le site n'est pas fermé globalement.",
            blockedAll ? "Retirez « Disallow: / » pour les robots que vous souhaitez accueillir." : nil, w: 4)

        // ---------- Fiche ----------
        var facts: [Fact] = [
            Fact(label: "Adresse analysée", value: page.finalURL.absoluteString),
            Fact(label: "Code serveur", value: "\(page.status)"),
            Fact(label: "Temps de réponse", value: String(format: "%.2f s", page.seconds)),
            Fact(label: "Poids du HTML", value: String(format: "%.0f Ko", kb)),
            Fact(label: "Mots de texte visible", value: "\(doc.words)"),
            Fact(label: "Titre", value: doc.title.isEmpty ? "—" : doc.title),
            Fact(label: "H1 / H2 / H3", value: "\(doc.h1s.count) / \(doc.h2Count) / \(doc.h3Count)"),
            Fact(label: "Liens internes / externes", value: "\(doc.internalLinks) / \(doc.externalLinks)"),
            Fact(label: "Images (sans alt)", value: "\(doc.imagesTotal) (\(doc.imagesMissingAlt))"),
            Fact(label: "Langue", value: doc.lang.isEmpty ? "—" : doc.lang),
            Fact(label: "Schémas détectés", value: doc.schemaTypes.isEmpty ? "aucun" : doc.schemaTypes.sorted().joined(separator: ", ")),
        ]
        if let s = robots?.sitemaps.first { facts.append(Fact(label: "Sitemap déclaré", value: s)) }

        return Report(inputURL: input, finalURL: page.finalURL.absoluteString, date: Date(), checks: checks, facts: facts,
                      isDemo: isDemo, outlinks: doc.outlinks)
    }
}
