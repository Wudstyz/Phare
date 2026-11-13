<div align="center">

<img src="docs/icon-256.png" width="128" alt="Phare icon">

# Phare

**Shine a light on your website, for Google and for AI.**

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey) ![MIT License](https://img.shields.io/badge/license-MIT-green)

[Version française](README.md)

<img src="docs/screenshots/01-priorites.png" width="760" alt="Phare: scores and priorities">

</div>

Phare is a free Mac app that audits a website on three axes:

- **SEO**: classic search optimisation (Google, Bing): title, description, headings, mobile, speed, sitemap…
- **GSO** (*Generative Search Optimization*): how easy is the site to cite for ChatGPT, Claude, Perplexity, Gemini…? Structured data, FAQ, author, dates, figures, `llms.txt`…
- **AI access**: can AI crawlers (OAI-SearchBot, ClaudeBot, PerplexityBot, GPTBot…) read your site according to `robots.txt`? Is the content readable without JavaScript?

You get three scores out of 100, a global score and a **priority list** with advice for each item. Reports export to Markdown.

Two modes, chosen at the top of the window:

- **Une page** (one page): analyses the given address.
- **Tout le site** (whole site): reads `sitemap.xml`, analyses a sample of pages (up to 20, 50, 100 or 200) and shows a **table ranked from the weakest page to the best**. Click a row to open that page's detailed analysis. The **Problèmes récurrents** tab lists issues repeated across pages, including duplicate titles.

Whole-site mode adds two more tabs:

- **Maillage** (internal linking): broken links, links going through a redirect, orphan pages (nothing links to them), pages more than 3 clicks from the home page, empty or generic link texts ("click here"). Phare also checks up to 100 linked-but-not-analysed addresses. The "Entrants" (inbound) column in the table shows how many pages link to each page.
- **Backlinks**: import the "External links" export from **Google Search Console** (free, for your own site) to see who links to you, your most linked pages and anchor texts. A fictional sample is in [`examples/`](examples).

Every report also reminds you that backlinks are not measured by a single-page analysis, with a pointer on how to build them.

The analysis runs **on your Mac**: nothing is sent to a third-party service. The interface is in French.

## Screenshots

**Whole site: table of pages, weakest first, then one page in detail**

| Table | Page detail |
|---|---|
| <img src="docs/screenshots/06-site-pages.png"> | <img src="docs/screenshots/07-page-detail.png"> |
| **Internal linking** | **Backlinks (Search Console import)** |
| <img src="docs/screenshots/09-maillage.png"> | <img src="docs/screenshots/10-backlinks.png"> |

| SEO | GSO |
|---|---|
| <img src="docs/screenshots/02-seo.png"> | <img src="docs/screenshots/03-gso.png"> |
| **AI access** | **Technical sheet** |
| <img src="docs/screenshots/04-acces-ia.png"> | <img src="docs/screenshots/05-fiche.png"> |

## Install

1. Download `Phare.dmg` from the [latest release](../../releases/latest).
2. Open it and drag **Phare** to **Applications**.
3. First launch: the app is not notarised by Apple (no paid developer account). **Right-click → Open**, or in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Phare.app
```

Nothing else to install.

## Getting started

1. Type your site's address, then **Analyser**.
2. No site at hand? **Essayer la démo** analyses a fictional site offline.
3. Read the **Priorités** tab, fix, run again.
4. **Exporter le rapport…** saves a Markdown report.

## Compatibility and known limits

- Apple Silicon Macs (arm64). Built for macOS 13+, but **only tested on macOS 26** (a single Mac).
- In "Une page" mode, Phare analyses **the given page** plus `robots.txt`, `sitemap.xml` and `llms.txt`.
- In "Tout le site" mode, pages come **from the sitemap only** (Phare does not follow links): without a usable sitemap the mode stops with a message. Above the chosen maximum, an evenly spread sample is analysed, not every page. Requests are throttled (4 at a time, with a short pause) to avoid overloading the site.
- `robots.txt` and `llms.txt` checks are site-wide, so they show up on every page.
- **Backlinks**: Phare does not measure them itself (that needs an index of the whole web). It only reads the Google Search Console export you give it. Search Console shows only a sample of links and only works for a site you own. The CSV reader is tolerant (comma, semicolon, tab, `.zip`) but was **tested on sample files, not on a real Search Console export**: if a file is not recognised, the app says so.
- **Internal linking**: computed from the analysed pages. If the sample does not cover the whole sitemap, "pages without inbound links" needs confirming and click depth is an estimate. Links added by JavaScript are not seen. Only 100 non-analysed addresses are verified.
- It reads **raw HTML** without running JavaScript, like most AI crawlers. A fully JavaScript-rendered site will show little content; this is intentional and flagged.
- Phare does **not** query ChatGPT, Claude or Gemini to check whether your site is cited. Scores are **best-practice indicators**, not a visibility guarantee.
- `llms.txt` is an emerging standard; no AI vendor guarantees to use it.
- `robots.txt` rules are interpreted simply (prefixes, `*`, `$`); edge cases may differ.
- Demo mode (single page and whole site) and a live single-page read of `example.com` were tested; whole-site mode was tried on one real site (6 pages of an 84-page sitemap), not on large sites or very large sitemaps.

## Build from source

Requires Xcode (or command line tools) with Swift 6.

```bash
./build_app.sh   # builds build/Phare.app (ad-hoc signed)
./make_dmg.sh    # builds build/Phare.dmg + SHA-256
```

Console mode (testing):

```bash
build/Phare.app/Contents/MacOS/Phare --cli --demo
build/Phare.app/Contents/MacOS/Phare --cli https://example.com
```

## Code layout

| File | Role |
|---|---|
| `Sources/Phare/Analyzer.swift` | All SEO / GSO / AI-access checks, networking |
| `Sources/Phare/HTMLDoc.swift` | HTML, JSON-LD and `robots.txt` parsing |
| `Sources/Phare/Site.swift` | "Tout le site" mode: sitemap reading, multi-page analysis, ranking |
| `Sources/Phare/Backlinks.swift` | Google Search Console export reader (CSV / zip) |
| `Sources/Phare/Models.swift` | Scores, report, Markdown export |
| `Sources/Phare/Views.swift` | SwiftUI interface (light theme) |
| `Sources/Phare/DemoData.swift` | Fictional demo site |
| `tools/make_icon.swift` | Draws the icon |

## Contributing

Issues and pull requests are welcome. To add a check, add an `add(...)` call in `Analyzer.swift`.

## License

[MIT](LICENSE) © 2026 Wudstyz. See also [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
