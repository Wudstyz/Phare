<div align="center">

<img src="docs/icon-256.png" width="128" alt="Phare icon">

# Phare

**Shine a light on your website, for Google and for AI.**

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey) ![MIT License](https://img.shields.io/badge/license-MIT-green)

[Version française](README.md)

<img src="docs/screenshots/06-site-pages.png" width="760" alt="Phare: table of a site's pages, weakest first">

</div>

Phare is a free Mac app that audits a website on three axes, with around fifty checks:

- **SEO**: classic search optimisation (Google, Bing): tags, headings, mobile, speed, sitemap, links…
- **GSO** (*Generative Search Optimization*): how easy is the site to cite for ChatGPT, Claude, Perplexity, Gemini…? Structured data, FAQ, author, dates, figures, `llms.txt`…
- **AI access**: can AI crawlers read your site according to `robots.txt`? Is the content readable without JavaScript?

You get three scores out of 100, a global score and a **priority list** with advice for each item.

The analysis runs **on your Mac**: nothing is sent to a third-party service. The interface is in French.

> **Need help fixing the issues found?** [HPI Innovations](https://www.hpi-innovations.fr/?utm_source=github&utm_medium=readme&utm_campaign=phare) is available to help.

## Two modes

- **Une page** (one page): analyses the given address.
- **Tout le site** (whole site): reads `sitemap.xml`, analyses a sample of pages (up to 20, 50, 100 or 200) and shows a **table ranked from the weakest page to the best**. Click a row to open that page's detailed analysis. Four tabs:
  - **Pages**: the table (global score, SEO, GSO, AI access, inbound links, number of items to fix);
  - **Problèmes récurrents**: what repeats across pages, including duplicate titles;
  - **Maillage**: internal-linking audit (see below);
  - **Backlinks**: Google Search Console import (see below).

## What Phare checks

**SEO**: HTTPS, page reachable, `title` tag, meta description, H1, subheadings, canonical URL, indexing block (`noindex`), mobile display, language, image alt text, share preview (Open Graph), internal linking, link texts, content length, response speed, HTML weight, `robots.txt`, sitemap, favicon.

**GSO**: JSON-LD structured data and useful types (Organization, FAQPage, Article…), entity identity (`sameAs`), questions / FAQ, easy-to-cite content (lists, tables), direct answer at the top, author (E-E-A-T), publication dates, cited sources, figures and evidence, `llms.txt`.

**AI access**: whether each AI crawler listed below is allowed (from `robots.txt`, page by page), Googlebot and Bingbot, `noai` directive, content readable without JavaScript, site closed to all robots.

### AI crawlers checked

Phare reads `robots.txt` and tells you, for each crawler, whether it may access the page. A blocked **search** or **on-demand** crawler is flagged as a problem (you lose visibility in its answers). A blocked **training** crawler is only informational: it is a legitimate choice.

| Crawler | Vendor / purpose | Type |
|---|---|---|
| `OAI-SearchBot` | OpenAI, ChatGPT search | Search |
| `ChatGPT-User` | OpenAI, ChatGPT fetching a page | On demand |
| `GPTBot` | OpenAI, model training | Training |
| `Claude-SearchBot` | Anthropic, Claude search | Search |
| `Claude-User` | Anthropic, Claude fetching a page | On demand |
| `ClaudeBot` | Anthropic, model training | Training |
| `PerplexityBot` | Perplexity, search | Search |
| `Perplexity-User` | Perplexity, on-demand fetching | On demand |
| `Applebot` | Apple, Siri and Spotlight search | Search |
| `Amazonbot` | Amazon, Alexa answers | Search |
| `DuckAssistBot` | DuckDuckGo, DuckAssist answers | On demand |
| `MistralAI-User` | Mistral, Le Chat fetching a page | On demand |
| `Meta-ExternalFetcher` | Meta, on-demand fetching | On demand |
| `Google-Extended` | Google, Gemini training | Training |
| `Applebot-Extended` | Apple, Apple Intelligence training | Training |
| `CCBot` | Common Crawl, dataset used by many AIs | Training |
| `Bytespider` | ByteDance, training | Training |
| `meta-externalagent` | Meta, training | Training |
| `cohere-ai` | Cohere, training | Training |

Phare also checks `Googlebot` and `Bingbot` (Bing feeds several AI engines). Crawler names change over time: the list lives in `Sources/Phare/Analyzer.swift` (`aiBots`), and adding one takes a single line.

### Internal linking (whole-site mode)

Broken links, links going through a redirect, **orphan pages** (nothing links to them), pages more than 3 clicks from the home page, empty or generic link texts ("click here"). Phare also checks up to 100 linked-but-not-analysed addresses. The "Entrants" (inbound) column in the table shows how many pages link to each page.

### Backlinks (whole-site mode)

Phare cannot know who links to you: it only sees your site. Import the "External links" export from **Google Search Console** (free, for your own site, `.csv` or `.zip` files) to see who links to you, your most linked pages and anchor texts. Fictional samples are in [`examples/`](examples). Every report also reminds you that backlinks are not measured by a single-page analysis, with a pointer on how to build them.

### Detailed export

In whole-site mode, **Exporter le dossier complet…** creates a folder containing:

- `00-rapport-global.md`: site summary (average scores, recurring issues, internal linking, backlinks, page table linking to each report);
- `pages/`: **one detailed report per page** (full analysis, priorities, technical sheet, place in the site, linking: who links to the page, where it links, broken links);
- `pages.csv` and `problemes-par-page.csv`: spreadsheets for Excel or Numbers (one row per page, and one row per issue per page);
- `LISEZ-MOI.md`: explains the folder.

From the table, when you open one page, **Exporter cette page…** exports only that page's detailed report. In "Une page" mode, the export is a single Markdown file.

## Screenshots

<div align="center">

**Home** and **single-page analysis** (priorities)

<img src="docs/screenshots/00-accueil.png" width="380"> <img src="docs/screenshots/01-priorites.png" width="380">

**SEO** and **GSO**

<img src="docs/screenshots/02-seo.png" width="380"> <img src="docs/screenshots/03-gso.png" width="380">

**AI access** (crawlers) and **technical sheet**

<img src="docs/screenshots/04-acces-ia.png" width="380"> <img src="docs/screenshots/05-fiche.png" width="380">

**Whole site**: page table, then one page in detail

<img src="docs/screenshots/06-site-pages.png" width="380"> <img src="docs/screenshots/07-page-detail.png" width="380">

**Recurring issues**, **internal linking** and **backlinks**

<img src="docs/screenshots/08-problemes-recurrents.png" width="250"> <img src="docs/screenshots/09-maillage.png" width="250"> <img src="docs/screenshots/10-backlinks.png" width="250">

</div>

The screenshots show demo mode: a fictional site ("Atelier du Bois") analysed offline.

## Install

1. Download `Phare.dmg` from the [latest release](../../releases/latest).
2. Open it and drag **Phare** to **Applications**.
3. First launch: the app is not notarised by Apple (no paid developer account). **Right-click → Open**, or in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Phare.app
```

Nothing else to install.

## Getting started

1. Type your site's address (e.g. `www.mysite.com`), choose **Une page** or **Tout le site**, then **Analyser**.
2. No site at hand? **Essayer la démo** analyses a fictional site offline.
3. Read the **priorities**, fix, run again.
4. **Exporter** to keep a record (Markdown, plus CSV in whole-site mode).

## Contact banner

Once results are shown, a discreet banner offers the services of [HPI Innovations](https://www.hpi-innovations.fr/?utm_source=github&utm_medium=readme&utm_campaign=phare) (the author's company) to help fix the issues found, with a link to its website and an e-mail address. Nothing is sent unless you click: the link opens your browser, the address opens a new empty message in your mail app. The banner closes with the cross. In the source it is `promoBanner` in `Sources/Phare/Views.swift`: remove it if you build your own version.

## Compatibility and known limits

- Apple Silicon Macs (arm64). Built for macOS 13+, but **only tested on macOS 26** (a single Mac).
- In "Une page" mode, Phare analyses **the given page** plus `robots.txt`, `sitemap.xml` and `llms.txt`.
- In "Tout le site" mode, pages come **from the sitemap only** (Phare does not follow links): without a usable sitemap the mode stops with a message. Above the chosen maximum, an evenly spread sample is analysed, not every page. Requests are throttled (4 at a time, with a short pause) to avoid overloading the site.
- `robots.txt` and `llms.txt` checks are site-wide, so they show up on every page.
- Phare reads **raw HTML** without running JavaScript, like most AI crawlers. A fully JavaScript-rendered site will show little content; this is intentional and flagged. Links added by JavaScript are not seen.
- Phare does **not** query ChatGPT, Claude or Gemini to check whether your site is cited. Scores are **best-practice indicators**, not a visibility guarantee.
- `llms.txt` is an emerging standard; no AI vendor guarantees to use it.
- `robots.txt` rules are interpreted simply (prefixes, `*`, `$`); edge cases may differ. Crawler names and roles are those known at the time of writing: check the vendors' documentation.
- **Backlinks**: Phare does not measure them itself (that needs an index of the whole web). It only reads the Google Search Console export you give it. Search Console shows only a sample of links and only works for a site you own. The CSV reader is tolerant (comma, semicolon, tab, `.zip`) but was **tested on sample files, not on a real Search Console export**: if a file is not recognised, the app says so.
- **Internal linking**: computed from the analysed pages. If the sample does not cover the whole sitemap, "pages without inbound links" needs confirming and click depth is an estimate. Only 100 non-analysed addresses are verified.
- **What was tested**: demo mode (single page and whole site), a live single-page read of `example.com`, whole-site mode on one real site (6 pages of an 84-page sitemap), and the folder export. The exported CSV files were not opened in Excel itself. No tests on large sites or very large sitemaps.

## Build from source

Requires Xcode (or command line tools) with Swift 6.

```bash
./build_app.sh   # builds build/Phare.app (ad-hoc signed)
./make_dmg.sh    # builds build/Phare.dmg + SHA-256
```

Console mode (testing):

```bash
build/Phare.app/Contents/MacOS/Phare --cli --demo
build/Phare.app/Contents/MacOS/Phare --cli --site --demo
build/Phare.app/Contents/MacOS/Phare --cli --site --max=30 https://example.com
build/Phare.app/Contents/MacOS/Phare --cli --site --demo --export=/path/to/folder
```

## Code layout

| File | Role |
|---|---|
| `Sources/Phare/Analyzer.swift` | SEO / GSO / AI-access checks, AI crawler list, networking |
| `Sources/Phare/HTMLDoc.swift` | HTML (including links), JSON-LD and `robots.txt` parsing |
| `Sources/Phare/Site.swift` | "Tout le site" mode: sitemap, multi-page analysis, internal-linking audit, ranking |
| `Sources/Phare/Backlinks.swift` | Google Search Console export reader (CSV / zip) |
| `Sources/Phare/Export.swift` | Folder export: global report, one report per page, CSV |
| `Sources/Phare/Models.swift` | Scores, report, single-page Markdown export |
| `Sources/Phare/Views.swift` | SwiftUI interface (light theme), contact banner |
| `Sources/Phare/DemoData.swift` | Fictional demo site |
| `tools/make_icon.swift` | Draws the icon |

## Contributing

Issues and pull requests are welcome. To add a check, add an `add(...)` call in `Analyzer.swift`; to add an AI crawler, one line in `aiBots`.

## License

[MIT](LICENSE) © 2026 Wudstyz. See also [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
