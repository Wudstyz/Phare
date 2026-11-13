import Foundation
import SwiftUI

// Mode console pour les tests : Phare --cli --demo   ou   Phare --cli https://exemple.fr
let args = CommandLine.arguments
if args.contains("--cli") {
    let demo = args.contains("--demo")
    let target = args.last(where: { !$0.hasPrefix("--") && $0 != args[0] }) ?? DemoData.url
    Task {
        do {
            let a = Analyzer(fetch: demo ? DemoData.fetch : liveFetch, isDemo: demo)
            let r = try await a.run(demo ? DemoData.url : target)
            print(r.markdown())
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
