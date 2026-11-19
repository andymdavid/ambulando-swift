import Foundation

/// UX lab: the Deck greeting by time of day ("Good evening, Maya") instead of "Welcome …, where will we focus today?".
enum DeckGreeting {
    static func line(name: String?, now: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return part }
        return "\(part), \(name)"
    }
}
