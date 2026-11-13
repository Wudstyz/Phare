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

L'analyse se fait **depuis votre Mac** : aucune donnée n'est envoyée à un service tiers.

## Captures

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
- Phare analyse **la page indiquée** (en général l'accueil) et les fichiers `robots.txt`, `sitemap.xml`, `llms.txt`. Il n'explore pas tout le site.
- Il lit le HTML **brut**, sans exécuter JavaScript, comme le font la plupart des robots d'IA. Un site entièrement construit en JavaScript aura donc peu de contenu visible : c'est voulu, et signalé.
- Phare **n'interroge pas** ChatGPT, Claude ou Gemini pour savoir si votre site y est cité. Les scores sont des **indicateurs de bonnes pratiques**, pas une garantie de visibilité.
- `llms.txt` est un standard émergent : aucune IA ne garantit l'utiliser.
- Les règles de `robots.txt` sont interprétées de façon simple (préfixes, `*`, `$`) ; les cas très particuliers peuvent différer.
- Le mode démo et la lecture d'un vrai site (`example.com`) ont été testés ; les autres sites réels, non.

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
| `Sources/Phare/Models.swift` | Scores, rapport, export Markdown |
| `Sources/Phare/Views.swift` | Interface SwiftUI (thème clair) |
| `Sources/Phare/DemoData.swift` | Site fictif du mode démo |
| `tools/make_icon.swift` | Dessine l'icône |

## Contribuer

Les idées et corrections sont les bienvenues via les *issues* et *pull requests*. Pour ajouter une vérification, ajoutez un appel `add(...)` dans `Analyzer.swift`.

## Licence

[MIT](LICENSE) © 2026 Wudstyz. Voir aussi [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
