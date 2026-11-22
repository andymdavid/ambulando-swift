import Observation

/// UX lab: a "New task" or "New document" asked for from outside its section (the Mac command menu). The section's
/// list takes it when it appears, or at once when it is already showing.
@MainActor @Observable final class UXComposeRequest {
    static let shared = UXComposeRequest()
    /// "task" or "doc".
    var pending: String?

    func take(_ kind: String) -> Bool {
        guard pending == kind else { return false }
        pending = nil
        return true
    }
}
