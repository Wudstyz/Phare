<div align="center">

<img src="docs/icon-256.png" width="128" alt="Icône de Phare">

# Phare

**Éclairez votre site pour Google et pour les IA.**

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey) ![Licence MIT](https://img.shields.io/badge/licence-MIT-green)

[English version](README.en.md)

<img src="docs/screenshots/01-priorites.png" width="760" alt="Phare : scores et priorités">

</div>

Phare est une app Mac gratuite qui analyse un site web sur trois axes :

- **SEO** : le référencement classique (Google, Bing) : title, description, titres, mobile, vitesse, sitemap…
- **GSO** (*Generative Search Optimization*) : le site est-il facile à citer par ChatGPT, Claude, Perplexity, Gemini… ? Données structurées, FAQ, auteur, dates, chiffres, `llms.txt`…
- **Accès IA** : les robots d'IA (OAI-SearchBot, ClaudeBot, PerplexityBot, GPTBot…) peuvent-ils lire votre site d'après `robots.txt` ? Le contenu est-il lisible sans JavaScript ?

Vous obtenez 3 scores sur 100, un score global, et une liste de **priorités** avec le conseil pour chaque point. Le rapport s'exporte en Markdown.

Deux modes, au choix en haut de la fenêtre :

- **Une page** : analyse l'adresse indiquée.
- **Tout le site** : lit le `sitemap.xml`, analyse un échantillon de pages (20, 50, 100 ou 200 au maximum) et affiche un **tableau classé de la page la plus faible à la meilleure**. Un clic sur une ligne ouvre l'analyse détaillée de la page. L'onglet **Problèmes récurrents** liste ce qui revient sur plusieurs pages, y compris les titres en double.

En mode « Tout le site », deux onglets de plus :

- **Maillage** : audit des liens internes. Liens cassés, liens qui passent par une redirection, pages orphelines (aucun lien ne mène vers elles), pages à plus de 3 clics de l'accueil, textes de lien vides ou génériques (« cliquez ici »). Phare vérifie aussi jusqu'à 100 adresses liées mais non analysées. La colonne « Entrants » du tableau donne le nombre de pages qui pointent vers chaque page.
- **Backlinks** : importez l'export « Liens externes » de **Google Search Console** (gratuit, pour votre propre site) pour voir les sites qui vous citent, vos pages les plus liées et les textes d'ancrage. Un fichier d'essai fictif est dans [`examples/`](examples).

Chaque rapport rappelle aussi que les backlinks ne sont pas mesurés par l'analyse d'une page seule, avec une piste pour les travailler.

L'analyse se fait **depuis votre Mac** : aucune donnée n'est envoyée à un service tiers.

## Captures

**Tout le site : tableau des pages, de la plus faible à la meilleure, puis détail d'une page**

| Tableau | Détail d'une page |
|---|---|
| <img src="docs/screenshots/06-site-pages.png"> | <img src="docs/screenshots/07-page-detail.png"> |
| **Maillage interne** | **Backlinks (import Search Console)** |
| <img src="docs/screenshots/09-maillage.png"> | <img src="docs/screenshots/10-backlinks.png"> |

| SEO | GSO |
|---|---|
| <img src="docs/screenshots/02-seo.png"> | <img src="docs/screenshots/03-gso.png"> |
| **Accès IA** | **Fiche technique** |
| <img src="docs/screenshots/04-acces-ia.png"> | <img src="docs/screenshots/05-fiche.png"> |

## Installation

1. Téléchargez `Phare.dmg` dans la [dernière version](../../releases/latest).
2. Ouvrez le `.dmg` et glissez **Phare** dans **Applications**.
3. Première ouverture : l'app n'est pas notarisée par Apple (pas de compte développeur payant). Faites **clic droit → Ouvrir**, ou dans le Terminal :

```bash
xattr -dr com.apple.quarantine /Applications/Phare.app
```

Rien d'autre à installer.

## Premiers pas

1. Tapez l'adresse de votre site (ex. `www.monsite.fr`) puis **Analyser**.
2. Pas de site sous la main ? **Essayer la démo** : un site fictif analysé sans Internet.
3. Lisez l'onglet **Priorités**, corrigez, relancez.
4. **Exporter le rapport…** pour garder une trace en Markdown.

## Compatibilité et limites connues

- Mac Apple Silicon (arm64). Le programme est compilé pour macOS 13 minimum, mais **testé uniquement sur macOS 26** (un seul Mac).
- En mode « Une page », Phare analyse **la page indiquée** et les fichiers `robots.txt`, `sitemap.xml`, `llms.txt`.
- En mode « Tout le site », les pages viennent **du sitemap uniquement** (Phare ne suit pas les liens) : sans sitemap exploitable, le mode s'arrête avec un message. Au-delà du maximum choisi, un échantillon réparti sur la liste est analysé, pas toutes les pages. Les requêtes sont limitées (4 à la fois, avec une courte pause) pour ne pas surcharger le site.
- Les contrôles de `robots.txt` et `llms.txt` sont communs à tout le site : ils apparaissent donc sur chaque page.
- **Backlinks** : Phare ne les mesure pas lui-même (il faudrait un index du web entier). Il lit seulement l'export Google Search Console que vous lui donnez. Search Console ne montre qu'un échantillon des liens, et ne fonctionne que pour un site dont vous êtes propriétaire. Le lecteur de CSV est tolérant (virgule, point-virgule, tabulation, `.zip`) mais a été **testé sur des fichiers d'exemple, pas sur un vrai export Search Console** : si un fichier n'est pas reconnu, l'app l'indique.
- **Maillage** : calculé à partir des pages analysées. Si l'échantillon ne couvre pas tout le sitemap, « pages sans lien entrant » est à confirmer, et la profondeur de clics est une estimation. Les liens ajoutés par JavaScript ne sont pas vus. Seules 100 adresses non analysées sont vérifiées.
- Il lit le HTML **brut**, sans exécuter JavaScript, comme le font la plupart des robots d'IA. Un site entièrement construit en JavaScript aura donc peu de contenu visible : c'est voulu, et signalé.
- Phare **n'interroge pas** ChatGPT, Claude ou Gemini pour savoir si votre site y est cité. Les scores sont des **indicateurs de bonnes pratiques**, pas une garantie de visibilité.
- `llms.txt` est un standard émergent : aucune IA ne garantit l'utiliser.
- Les règles de `robots.txt` sont interprétées de façon simple (préfixes, `*`, `$`) ; les cas très particuliers peuvent différer.
- Le mode démo (une page et tout le site) et la lecture d'un vrai site en mode « Une page » (`example.com`) ont été testés ; le mode « Tout le site » a été essayé sur un vrai site (6 pages d'un sitemap de 84), pas sur de gros sites ni avec des sitemaps très volumineux.

## Construire depuis les sources

Prérequis : Xcode (ou ses outils en ligne de commande) avec Swift 6.

```bash
./build_app.sh   # construit build/Phare.app (signature ad hoc)
./make_dmg.sh    # construit build/Phare.dmg + somme SHA-256
```

Mode console (tests) :

```bash
build/Phare.app/Contents/MacOS/Phare --cli --demo
build/Phare.app/Contents/MacOS/Phare --cli https://example.com
```

## Organisation du code

| Fichier | Rôle |
|---|---|
| `Sources/Phare/Analyzer.swift` | Toutes les vérifications SEO / GSO / Accès IA, récupération réseau |
| `Sources/Phare/HTMLDoc.swift` | Lecture du HTML, du JSON-LD et de `robots.txt` |
| `Sources/Phare/Site.swift` | Mode « Tout le site » : lecture du sitemap, analyse de plusieurs pages, classement |
| `Sources/Phare/Backlinks.swift` | Lecture de l'export Google Search Console (CSV / zip) |
| `Sources/Phare/Models.swift` | Scores, rapport, export Markdown |
| `Sources/Phare/Views.swift` | Interface SwiftUI (thème clair) |
| `Sources/Phare/DemoData.swift` | Site fictif du mode démo |
| `tools/make_icon.swift` | Dessine l'icône |

## Contribuer

Les idées et corrections sont les bienvenues via les *issues* et *pull requests*. Pour ajouter une vérification, ajoutez un appel `add(...)` dans `Analyzer.swift`.

## Licence

[MIT](LICENSE) © 2026 Wudstyz. Voir aussi [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
