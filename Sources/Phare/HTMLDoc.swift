import Foundation

func regexMatches(_ pattern: String, in s: String, group: Int = 0) -> [String] {
    guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
    let ns = s as NSString
    return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
        let r = m.range(at: group)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
}

func parseAttributes(_ tag: String) -> [String: String] {
    guard let re = try? NSRegularExpression(pattern: #"([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)')"#) else { return [:] }
    let ns = tag as NSString
    var out: [String: String] = [:]
    for m in re.matches(in: tag, range: NSRange(location: 0, length: ns.length)) {
        let key = ns.substring(with: m.range(at: 1)).lowercased()
        var value = ""
        if m.range(at: 2).location != NSNotFound { value = ns.substring(with: m.range(at: 2)) }
        else if m.range(at: 3).location != NSNotFound { value = ns.substring(with: m.range(at: 3)) }
        out[key] = value
    }
    return out
}

func decodeEntities(_ s: String) -> String {
    var r = s
    for (a, b) in [("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&rsquo;", "’"), ("&eacute;", "é")] {
        r = r.replacingOccurrences(of: a, with: b)
    }
    return r
}

func stripTags(_ s: String) -> String {
    let t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    return decodeEntities(t).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
}

struct HTMLDoc {
    var title = ""
    var metaDescription = ""
    var lang = ""
    var canonical = ""
    var robotsMeta = ""
    var viewport = ""
    var h1s: [String] = []
    var h2Count = 0
    var h3Count = 0
    var questionHeadings = 0
    var imagesTotal = 0
    var imagesMissingAlt = 0
    var internalLinks = 0
    var externalLinks = 0
    var words = 0
    var listCount = 0
    var tableCount = 0
    var firstParagraphWords = 0
    var statCount = 0
    var scriptCount = 0
    var ogTitle = false
    var ogDescription = false
    var ogImage = false
    var hasFavicon = false
    var hasAuthor = false
    var hasDates = false
    var schemaTypes: Set<String> = []
    var hasSameAs = false
    var jsonLDBlocks = 0

    init(_ html: String, host: String) {
        title = stripTags(regexMatches(#"<title[^>]*>(.*?)</title>"#, in: html, group: 1).first ?? "")
        lang = parseAttributes(regexMatches(#"<html\b[^>]*>"#, in: html).first ?? "")["lang"] ?? ""

        var metas: [String: String] = [:]
        for tag in regexMatches(#"<meta\b[^>]*>"#, in: html) {
            let a = parseAttributes(tag)
            let key = (a["name"] ?? a["property"] ?? "").lowercased()
            if !key.isEmpty, let c = a["content"] { metas[key] = c }
        }
        metaDescription = metas["description"] ?? ""
        robotsMeta = (metas["robots"] ?? "").lowercased()
        viewport = metas["viewport"] ?? ""
        ogTitle = metas["og:title"] != nil
        ogDescription = metas["og:description"] != nil
        ogImage = metas["og:image"] != nil
        hasAuthor = metas["author"] != nil
        hasDates = metas["article:published_time"] != nil || metas["article:modified_time"] != nil

        for tag in regexMatches(#"<link\b[^>]*>"#, in: html) {
            let a = parseAttributes(tag)
            let rel = (a["rel"] ?? "").lowercased()
            if rel == "canonical" { canonical = a["href"] ?? "" }
            if rel.contains("icon") { hasFavicon = true }
            if rel == "author" { hasAuthor = true }
        }

        h1s = regexMatches(#"<h1\b[^>]*>(.*?)</h1>"#, in: html, group: 1).map(stripTags)
        let h2 = regexMatches(#"<h2\b[^>]*>(.*?)</h2>"#, in: html, group: 1).map(stripTags)
        let h3 = regexMatches(#"<h3\b[^>]*>(.*?)</h3>"#, in: html, group: 1).map(stripTags)
        h2Count = h2.count
        h3Count = h3.count
        questionHeadings = (h2 + h3).filter { $0.hasSuffix("?") }.count

        for tag in regexMatches(#"<img\b[^>]*>"#, in: html) {
            imagesTotal += 1
            let alt = parseAttributes(tag)["alt"] ?? ""
            if alt.trimmingCharacters(in: .whitespaces).isEmpty { imagesMissingAlt += 1 }
        }

        let bareHost = host.lowercased().replacingOccurrences(of: "www.", with: "")
        for tag in regexMatches(#"<a\b[^>]*>"#, in: html) {
            guard let href = parseAttributes(tag)["href"]?.trimmingCharacters(in: .whitespaces), !href.isEmpty else { continue }
            let low = href.lowercased()
            if low.hasPrefix("#") || low.hasPrefix("mailto:") || low.hasPrefix("tel:") || low.hasPrefix("javascript:") { continue }
            if low.hasPrefix("http://") || low.hasPrefix("https://") || low.hasPrefix("//") {
                let h = URL(string: low.hasPrefix("//") ? "https:" + low : low)?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
                if h == bareHost { internalLinks += 1 } else { externalLinks += 1 }
            } else {
                internalLinks += 1
            }
        }

        listCount = regexMatches(#"<(ul|ol)\b"#, in: html).count
        tableCount = regexMatches(#"<table\b"#, in: html).count
        scriptCount = regexMatches(#"<script\b"#, in: html).count
        if !hasDates { hasDates = !regexMatches(#"<time\b"#, in: html).isEmpty }

        // Texte visible
        var body = html
        for p in [#"<script\b.*?</script>"#, #"<style\b.*?</style>"#, #"<noscript\b.*?</noscript>"#, #"<svg\b.*?</svg>"#, #"<!--.*?-->"#] {
            body = body.replacingOccurrences(of: p, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        let text = stripTags(body)
        words = text.split(separator: " ").count
        statCount = regexMatches(#"\b\d[\d.,]*\s?(%|€|\$|ans\b|clients\b|projets\b|km\b|kg\b|m²)"#, in: text).count

        let paragraphs = regexMatches(#"<p\b[^>]*>(.*?)</p>"#, in: body, group: 1).map(stripTags)
        firstParagraphWords = paragraphs.first(where: { $0.split(separator: " ").count >= 8 })?.split(separator: " ").count ?? 0

        // JSON-LD
        let blocks = regexMatches(#"<script\b[^>]*application/ld\+json[^>]*>(.*?)</script>"#, in: html, group: 1)
        jsonLDBlocks = blocks.count
        var keys: Set<String> = []
        for b in blocks {
            if let data = b.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                HTMLDoc.walk(obj, types: &schemaTypes, keys: &keys)
            }
        }
        hasSameAs = keys.contains("sameAs")
        if keys.contains("author") || schemaTypes.contains("Person") { hasAuthor = true }
        if keys.contains("datePublished") || keys.contains("dateModified") { hasDates = true }
    }

    static func walk(_ any: Any, types: inout Set<String>, keys: inout Set<String>) {
        if let d = any as? [String: Any] {
            for (k, v) in d {
                keys.insert(k)
                if k == "@type" {
                    if let s = v as? String { types.insert(s) }
                    else if let a = v as? [String] { a.forEach { types.insert($0) } }
                } else {
                    walk(v, types: &types, keys: &keys)
                }
            }
        } else if let a = any as? [Any] {
            for x in a { walk(x, types: &types, keys: &keys) }
        }
    }
}

struct Robots {
    private var groups: [(agents: [String], rules: [(allow: Bool, path: String)])] = []
    var sitemaps: [String] = []

    init(_ text: String) {
        var lastWasAgent = false
        for raw in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            var line = String(raw)
            if let i = line.firstIndex(of: "#") { line = String(line[..<i]) }
            guard let c = line.firstIndex(of: ":") else { continue }
            let key = line[..<c].trimmingCharacters(in: .whitespaces).lowercased()
            let val = line[line.index(after: c)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "user-agent":
                if lastWasAgent, !groups.isEmpty { groups[groups.count - 1].agents.append(val.lowercased()) }
                else { groups.append((agents: [val.lowercased()], rules: [])) }
                lastWasAgent = true
            case "allow", "disallow":
                lastWasAgent = false
                if !groups.isEmpty, !val.isEmpty { groups[groups.count - 1].rules.append((allow: key == "allow", path: val)) }
            case "sitemap":
                sitemaps.append(val)
            default:
                lastWasAgent = false
            }
        }
    }

    func allowed(agent: String, path: String = "/") -> Bool {
        let a = agent.lowercased()
        let group = groups.first(where: { $0.agents.contains(a) }) ?? groups.first(where: { $0.agents.contains("*") })
        guard let g = group else { return true }
        var best: (len: Int, allow: Bool)?
        for r in g.rules {
            var pat = NSRegularExpression.escapedPattern(for: r.path)
            pat = pat.replacingOccurrences(of: "\\*", with: ".*").replacingOccurrences(of: "\\$", with: "$")
            guard path.range(of: "^" + pat, options: .regularExpression) != nil else { continue }
            let len = r.path.count
            if best == nil || len > best!.len || (len == best!.len && r.allow) { best = (len, r.allow) }
        }
        return best?.allow ?? true
    }
}
