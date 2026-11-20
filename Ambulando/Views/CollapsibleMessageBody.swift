import SwiftUI

/// UX lab: in a channel's conversation list, a long body (agent briefs, research notes) shows its first few lines with
/// a fade and "Read more"; opening the conversation shows it in full. Short bodies are untouched.
struct CollapsibleMessageBody<Content: View>: View {
    let enabled: Bool
    @ViewBuilder let content: () -> Content
    @State private var fullHeight: CGFloat = 0

    /// About five lines of body text at the Mac scale.
    private static var limit: CGFloat { 112 * TextScale.shared.factor }
    /// Only collapse when it hides a meaningful amount (not one stray line).
    private var long: Bool { fullHeight > Self.limit + 28 }

    var body: some View {
        if enabled {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 6, content: content)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { proxy in Color.clear.preference(key: BodyHeightKey.self, value: proxy.size.height) })
                    .frame(maxHeight: long ? Self.limit : nil, alignment: .top)
                    .clipped()
                    .mask {
                        if long {
                            LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                           startPoint: .top, endPoint: .bottom)
                        } else {
                            Color.black
                        }
                    }
                    .onPreferenceChange(BodyHeightKey.self) { fullHeight = $0 }
                if long {
                    // The whole conversation opens the thread, where the full text is; this says so.
                    Text("Read more")
                        .font(.amb(.caption).weight(.medium)).foregroundStyle(Amb.primary)
                        .padding(.vertical, 2)
                        .accessibilityIdentifier("message.readMore")
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6, content: content)
        }
    }
}

private struct BodyHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// UX lab: a thread title derived from a message body reads as plain text (no "## " heading marks or emphasis).
enum ThreadTitleText {
    static func clean(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        var title = line
        while let first = title.first, "#>-*".contains(first) { title.removeFirst() }
        title = title.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "").replacingOccurrences(of: "`", with: "")
        return title.trimmingCharacters(in: .whitespaces)
    }
}
