import Foundation

struct CountedItem: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

/// Données importées depuis l'export « Liens externes » de Google Search Console.
struct BacklinkData {
    var sites: [CountedItem] = []     // sites référents
    var pages: [CountedItem] = []     // pages de votre site qui reçoivent des liens
    var anchors: [CountedItem] = []   // textes d'ancrage
    var filesRead: [String] = []
    var skipped: [String] = []

    var isEmpty: Bool { sites.isEmpty && pages.isEmpty && anchors.isEmpty }
    var totalLinks: Int {
        if !sites.isEmpty { return sites.reduce(0) { $0 + $1.count } }
        return pages.reduce(0) { $0 + $1.count }
    }

    /// Nombre de liens connus vers une page (0 si absente de l'export).
    func linkCount(forPageKey key: String) -> Int {
        pages.first(where: { item in
            guard let u = URL(string: item.name) else { return false }
            return Analyzer.key(u) == key
        })?.count ?? 0
    }
}

enum BacklinkParser {
    // MARK: Lecture CSV tolérante

    static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        for enc in [String.Encoding.utf8, .utf16, .isoLatin1] {
            if let s = String(data: data, encoding: enc) { return s.replacingOccurrences(of: "\u{FEFF}", with: "") }
        }
        return nil
    }

    static func parseCSV(_ text: String) -> [[String]] {
        let first = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let candidates: [Character] = [",", ";", "\t"]
        let delim = candidates.max { a, b in first.filter { $0 == a }.count < first.filter { $0 == b }.count } ?? ","

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"" {
                quoted = true
            } else if c == delim {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
                row = []
            } else { field.append(c) }
            i += 1
        }
        row.append(field)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
        return rows
    }

    static func number(_ s: String) -> Int? {
        let digits = s.filter { $0.isNumber }
        let allowed = s.allSatisfy { $0.isNumber || " \u{00A0},.\u{202F}".contains($0) }
        guard allowed, !digits.isEmpty else { return nil }
        return Int(digits)
    }

    enum Kind { case sites, pages, anchors }

    static func classify(values: [String], header: String) -> Kind {
        let h = header.lowercased()
        if h.contains("ancrage") || h.contains("anchor") { return .anchors }
        let vals = values.filter { !$0.isEmpty }
        guard !vals.isEmpty else { return .anchors }
        let urls = vals.filter { $0.lowercased().hasPrefix("http") }.count
        if Double(urls) / Double(vals.count) >= 0.6 { return .pages }
        let domain = vals.filter { $0.range(of: #"^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil }.count
        if Double(domain) / Double(vals.count) >= 0.6 { return .sites }
        return .anchors
    }

    /// `files` : (nom du fichier, contenu texte).
    static func parse(files: [(name: String, text: String)]) -> BacklinkData {
        var data = BacklinkData()
        for f in files {
            let lower = f.name.lowercased()
            if lower.contains("intern") {
                data.skipped.append("\(f.name) (liens internes : ignoré, utilisez le rapport « Liens externes »)")
                continue
            }
            let rows = parseCSV(f.text)
            guard rows.count >= 2, rows[0].count >= 2 else {
                data.skipped.append("\(f.name) (format non reconnu)")
                continue
            }
            let body = Array(rows.dropFirst())
            let names = body.map { $0[0].trimmingCharacters(in: .whitespacesAndNewlines) }
            // première colonne numérique après la première
            var countCol: Int?
            for c in 1..<rows[0].count {
                let col = body.compactMap { $0.count > c ? $0[c] : nil }
                if !col.isEmpty, col.allSatisfy({ number($0) != nil }) { countCol = c; break }
            }
            guard let cc = countCol else {
                data.skipped.append("\(f.name) (pas de colonne de nombres)")
                continue
            }
            let items: [CountedItem] = body.compactMap { r in
                guard r.count > cc, let n = number(r[cc]) else { return nil }
                let name = r[0].trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : CountedItem(name: name, count: n)
            }.sorted { $0.count > $1.count }
            switch classify(values: names, header: rows[0][0]) {
            case .sites: data.sites += items
            case .pages: data.pages += items
            case .anchors: data.anchors += items
            }
            data.filesRead.append(f.name)
        }
        return data
    }

    /// Lit des fichiers .csv ou .zip choisis par l'utilisateur.
    static func load(urls: [URL]) -> BacklinkData {
        var files: [(name: String, text: String)] = []
        var extra: [String] = []
        for u in urls {
            if u.pathExtension.lowercased() == "zip" {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("phare-" + UUID().uuidString)
                try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                p.arguments = ["-o", "-qq", u.path, "-d", tmp.path]
                try? p.run()
                p.waitUntilExit()
                let inner = (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
                for f in inner where f.pathExtension.lowercased() == "csv" {
                    if let t = readText(f) { files.append((f.lastPathComponent, t)) }
                }
                try? FileManager.default.removeItem(at: tmp)
                if inner.isEmpty { extra.append("\(u.lastPathComponent) (archive vide ou illisible)") }
            } else if let t = readText(u) {
                files.append((u.lastPathComponent, t))
            } else {
                extra.append("\(u.lastPathComponent) (illisible)")
            }
        }
        var d = parse(files: files)
        d.skipped += extra
        return d
    }
}
