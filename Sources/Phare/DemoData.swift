import Foundation

/// Site fictif utilisé par le mode démo : aucune connexion réseau.
enum DemoData {
    static let url = "https://www.atelier-du-bois-demo.fr"

    static let html = """
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="utf-8">
      <title>Atelier du Bois – Menuisier artisan, escaliers, cuisines, dressings et agencements sur mesure en Bretagne</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <link rel="icon" href="/favicon.ico">
      <meta property="og:title" content="Atelier du Bois">
      <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"LocalBusiness","name":"Atelier du Bois","url":"https://www.atelier-du-bois-demo.fr","telephone":"+33 2 00 00 00 00"}
      </script>
      <script src="/app.js"></script>
    </head>
    <body>
      <header><nav><a href="/">Accueil</a> <a href="/realisations">Réalisations</a> <a href="/devis">Devis</a> <a href="/contact">Contact</a></nav></header>
      <h1>Atelier du Bois</h1>
      <h1>Menuiserie sur mesure</h1>
      <p>Bienvenue sur le site de notre atelier. Nous fabriquons depuis 1998 des escaliers, des cuisines et des dressings sur mesure, entièrement conçus et posés par nos menuisiers.</p>
      <img src="/photos/escalier.jpg">
      <img src="/photos/cuisine.jpg" alt="Cuisine en chêne massif">
      <img src="/photos/dressing.jpg">
      <h2>Nos réalisations</h2>
      <p>Plus de 450 projets réalisés pour des particuliers et des professionnels, avec un délai moyen de 6 semaines entre la validation du devis et la pose. Nos clients nous confient aussi bien la rénovation d'un escalier ancien que l'agencement complet d'une maison neuve, avec un suivi personnalisé du premier rendez-vous à la livraison.</p>
      <ul><li>Escaliers en chêne, hêtre ou frêne</li><li>Cuisines et salles de bains</li><li>Dressings et bibliothèques</li></ul>
      <h2>Notre savoir-faire</h2>
      <p>Chaque meuble est dessiné sur mesure, usiné dans notre atelier puis monté chez vous. Nous travaillons exclusivement des bois issus de forêts gérées durablement et appliquons des finitions à base d'huiles naturelles. L'équipe compte 8 menuisiers formés aux techniques traditionnelles comme à la fabrication numérique.</p>
      <p>Contactez-nous pour un devis gratuit sous 48 h. Nous intervenons dans un rayon de 60 km autour de Rennes et répondons à toutes les demandes, des plus simples aux plus techniques, avec le même soin.</p>
      <footer><a href="/mentions-legales">Mentions légales</a> <a href="https://www.facebook.com/exemple">Facebook</a></footer>
    </body>
    </html>
    """

    static let robots = """
    User-agent: *
    Allow: /

    User-agent: GPTBot
    Disallow: /

    User-agent: CCBot
    Disallow: /

    User-agent: PerplexityBot
    Disallow: /

    Sitemap: https://www.atelier-du-bois-demo.fr/sitemap.xml
    """

    static let paths = ["/", "/realisations", "/devis", "/contact", "/blog/choisir-son-escalier", "/mentions-legales"]

    static let sitemap: String = {
        let urls = paths.map { "<url><loc>https://www.atelier-du-bois-demo.fr\($0)</loc></url>" }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\(urls)</urlset>"
    }()

    private static let filler = "Nous fabriquons depuis 1998 des escaliers, des cuisines et des dressings sur mesure, entièrement conçus et posés par nos menuisiers. Plus de 450 projets réalisés, un délai moyen de 6 semaines et un devis gratuit sous 48 h dans un rayon de 60 km autour de Rennes."

    private static func page(title: String, desc: String?, h1: String, body: String, schema: String = "", words: Int = 3) -> String {
        let d = desc.map { "<meta name=\"description\" content=\"\($0)\">" } ?? ""
        let text = String(repeating: "<p>" + filler + "</p>", count: words)
        return """
        <!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>\(title)</title>\(d)
        <meta name="viewport" content="width=device-width, initial-scale=1"><link rel="canonical" href="https://www.atelier-du-bois-demo.fr">
        \(schema)</head><body><a href="/">Accueil</a> <a href="/realisations">Réalisations</a> <a href="/devis">Devis</a> <a href="/contact">Contact</a> <a href="/blog/choisir-son-escalier">Blog</a>
        <h1>\(h1)</h1>\(body)\(text)</body></html>
        """
    }

    static let pages: [String: String] = [
        "/": html,
        "/realisations": page(title: "Nos réalisations – Atelier du Bois", desc: nil, h1: "Réalisations",
                              body: "<h2>Escaliers</h2><img src=\"/a.jpg\"><img src=\"/b.jpg\"><img src=\"/c.jpg\"><h2>Cuisines</h2><ul><li>Chêne</li><li>Hêtre</li></ul>"),
        "/devis": page(title: "Contact et devis – Atelier du Bois", desc: "Demandez un devis gratuit pour votre projet de menuiserie sur mesure, réponse sous 48 h.",
                       h1: "Demander un devis", body: "<h2>Votre projet</h2>"),
        "/contact": page(title: "Contact et devis – Atelier du Bois", desc: nil, h1: "Contact", body: "<h2>Nous trouver</h2>", words: 1),
        "/blog/choisir-son-escalier": page(
            title: "Comment choisir son escalier sur mesure ? Guide 2026",
            desc: "Bois, forme, budget : tout ce qu'il faut savoir pour choisir un escalier sur mesure, avec les prix moyens et les délais de fabrication.",
            h1: "Comment choisir son escalier sur mesure ?",
            body: "<h2>Quel bois choisir pour un escalier ?</h2><ul><li>Chêne</li><li>Hêtre</li></ul><h2>Quel budget prévoir ?</h2><table><tr><td>Droit</td><td>2 500 €</td></tr></table><h2>Combien de temps de fabrication ?</h2><p>Comptez 6 semaines en moyenne, avec 3 visites sur place.</p><a href=\"https://www.service-public.fr\">Service-public</a> <a href=\"https://www.ademe.fr\">ADEME</a> <time datetime=\"2026-03-10\">10 mars 2026</time>",
            schema: "<script type=\"application/ld+json\">{\"@context\":\"https://schema.org\",\"@graph\":[{\"@type\":\"Article\",\"author\":{\"@type\":\"Person\",\"name\":\"Jean Martin\"},\"datePublished\":\"2026-03-10\"},{\"@type\":\"FAQPage\"},{\"@type\":\"Organization\",\"sameAs\":[\"https://www.facebook.com/exemple\"]}]}</script>",
            words: 2),
        "/mentions-legales": page(title: "Mentions légales", desc: nil, h1: "Mentions légales", body: "", words: 1),
    ]

    static let fetch: FetchFn = { url in
        let base = URL(string: DemoData.url + url.path)!
        func ok(_ body: String, _ seconds: Double = 0.9) -> Fetched {
            Fetched(status: 200, headers: [:], body: body, finalURL: base, seconds: seconds, bytes: body.utf8.count)
        }
        switch url.path {
        case "/robots.txt": return ok(DemoData.robots)
        case "/sitemap.xml": return ok(DemoData.sitemap)
        case "": return ok(DemoData.html, 1.8)
        default:
            if let body = DemoData.pages[url.path] { return ok(body, url.path == "/" ? 1.8 : 0.7) }
            return Fetched(status: 404, headers: [:], body: "", finalURL: base, seconds: 0.2, bytes: 0)
        }
    }
}
