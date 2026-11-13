import Foundation
import SwiftUI

// Mode console pour les tests :
//   Phare --cli --demo                      une page (démo)
//   Phare --cli --site --demo               tout le site (démo)
//   Phare --cli --site --max=30 https://exemple.fr
let args = CommandLine.arguments
if args.contains("--cli") {
    let demo = args.contains("--demo")
    let site = args.contains("--site")
    let maxPages = args.first(where: { $0.hasPrefix("--max=") }).flatMap { Int($0.dropFirst(6)) } ?? 50
    let target = args.last(where: { !$0.hasPrefix("--") && $0 != args[0] }) ?? DemoData.url
    Task {
        do {
            let a = Analyzer(fetch: demo ? DemoData.fetch : liveFetch, isDemo: demo)
            let input = demo ? DemoData.url : target
            if site {
                let r = try await a.runSite(input, maxPages: maxPages) { done, total in
                    FileHandle.standardError.write(Data("\(done)/\(total)\n".utf8))
                }
                print(r.markdown())
            } else {
                print(try await a.run(input).markdown())
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("Erreur : \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
} else {
    PhareApp.main()
}
