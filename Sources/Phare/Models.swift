import Foundation

enum Pillar: String, CaseIterable, Identifiable {
    case seo = "SEO"
    case gso = "GSO"
    case ia = "Accès IA"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .seo: return "Référencement classique (Google, Bing…)"
        case .gso: return "Citabilité par les moteurs de réponse IA"
        case .ia: return "Accès des robots d'IA à votre site"
        }
    }
}

enum Status: Int {
    case ok, warn, fail, info

    var score: Double? {
        switch self {
        case .ok: return 1
        case .warn: return 0.5
        case .fail: return 0
        case .info: return nil
        }
    }

    var label: String {
        switch self {
        case .ok: return "OK"
        case .warn: return "À améliorer"
        case .fail: return "Problème"
        case .info: return "Info"
        }
    }
}

struct Check: Identifiable {
    let id = UUID()
    let pillar: Pillar
    let title: String
    let status: Status
    let detail: String
    let advice: String?
    let weight: Int
}

struct Fact: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct Report {
    let inputURL: String
    let finalURL: String
    let date: Date
    let checks: [Check]
    let facts: [Fact]
    let isDemo: Bool

    func score(_ pillar: Pillar) -> Int {
        let list = checks.filter { $0.pillar == pillar && $0.status.score != nil }
        let total = list.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        let got = list.reduce(0.0) { $0 + Double($1.weight) * ($1.status.score ?? 0) }
        return Int((got / Double(total) * 100).rounded())
    }

    var globalScore: Int {
        let s = Pillar.allCases.map { score($0) }
        return Int((Double(s.reduce(0, +)) / Double(s.count)).rounded())
    }

    var priorities: [Check] {
        checks
            .filter { $0.status == .fail || $0.status == .warn }
            .sorted {
                if $0.status != $1.status { return $0.status == .fail }
                return $0.weight > $1.weight
            }
    }

    static func grade(_ score: Int) -> String {
        switch score {
        case 80...: return "Très bon"
        case 60..<80: return "Correct"
        case 40..<60: return "À améliorer"
        default: return "Faible"
        }
    }

    func markdown() -> String {
        var out = "# Rapport Phare\n\n"
        out += "- Site : \(finalURL)\n"
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .short
        out += "- Date : \(f.string(from: date))\n"
        if isDemo { out += "- Mode démo (site fictif, aucun accès réseau)\n" }
        out += "\n## Scores\n\n"
        out += "- Global : \(globalScore)/100 (\(Report.grade(globalScore)))\n"
        for p in Pillar.allCases {
            out += "- \(p.rawValue) : \(score(p))/100 — \(p.subtitle)\n"
        }
        out += "\n## Priorités\n\n"
        if priorities.isEmpty { out += "Aucun point à corriger.\n" }
        for c in priorities {
            out += "- **[\(c.pillar.rawValue)] \(c.title)** (\(c.status.label)) — \(c.detail)"
            if let a = c.advice { out += " → \(a)" }
            out += "\n"
        }
        for p in Pillar.allCases {
            out += "\n## \(p.rawValue)\n\n"
            for c in checks where c.pillar == p {
                out += "- [\(c.status.label)] \(c.title) — \(c.detail)\n"
            }
        }
        out += "\n## Fiche technique\n\n"
        for fact in facts { out += "- \(fact.label) : \(fact.value)\n" }
        return out
    }
}
