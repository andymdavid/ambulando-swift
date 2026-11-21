import SwiftUI

/// UX lab (sample app only): open a record or a composer at launch, for screen captures without clicking.
/// `-UXOpen "task:Review the native inbox"` opens that task (or `doc:`, `file:` by title or name);
/// `-UXOpen "task:new"` or `doc:new` opens the New task / New document sheet. Fires once per launch.
@MainActor enum UXLabOpen {
    private static var done = false
    private static var request: (kind: String, name: String)? {
        guard FixtureEnvironment.requested, let value = UserDefaults.standard.string(forKey: "UXOpen"),
              let colon = value.firstIndex(of: ":") else { return nil }
        return (String(value[..<colon]), String(value[value.index(after: colon)...]))
    }

    static func record(kind: String, among records: [(id: String, name: String)], model: AppModel) {
        guard !done, let request, request.kind == kind, let match = records.first(where: { $0.name == request.name }) else { return }
        done = true
        model.openRecord(kind: kind, id: match.id)
    }

    static func create(kind: String) -> Bool {
        guard !done, let request, request.kind == kind, request.name == "new" else { return false }
        done = true
        return true
    }
}
