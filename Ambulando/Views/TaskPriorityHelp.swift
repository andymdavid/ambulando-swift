import AmbulandoCore

/// UX lab: one-line explanations of task sizes, shown as tooltips. Based on the "big rocks first" idea the names come
/// from.
extension TaskPriority {
    var help: String {
        switch self {
        case .rock: "Rock: the most important work. Do these first."
        case .pebble: "Pebble: important, but after the rocks."
        case .sand: "Sand: small tasks that fill the gaps."
        case .urgent: "Urgent: needs attention now."
        case .high: "High priority"
        case .normal: "Normal priority"
        case .low: "Low priority"
        }
    }

    /// The tooltip for all task sizes together (pickers and menus), one per line.
    static let sizesHelp = "Rock: the most important work. Do these first.\nPebble: important, but after the rocks.\nSand: small tasks that fill the gaps."
}
