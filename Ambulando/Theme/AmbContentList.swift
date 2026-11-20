import SwiftUI

/// UX lab (Mac): the pieces every content list shares (`Amb.ListLayout`): a header with filters on the left and the
/// screen's main action on the right, quiet section labels separated by space (never a rule), and rows with a hover
/// fill and an inset hairline between them.

/// Filters or a switch on the left, the main action on the right.
struct ContentListHeader<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: Amb.Space.s) { content() }
            .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
            .padding(.top, Amb.Space.m).padding(.bottom, Amb.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Amb.background)
    }
}

/// A section's label: an optional mark, the name and a count, in metadata type. Space above it, no rule.
struct ContentListSectionLabel<Mark: View>: View {
    let title: String
    var count: Int? = nil
    @ViewBuilder var mark: () -> Mark

    var body: some View {
        HStack(spacing: Amb.Space.s) {
            mark()
            Text(title).foregroundStyle(Amb.secondaryForeground)
            if let count { Text("\(count)").foregroundStyle(Amb.faint).monospacedDigit() }
        }
        .font(.amb(.footnote).weight(.medium))
        .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
        .padding(.top, Amb.ListLayout.sectionTop).padding(.bottom, Amb.ListLayout.sectionBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension ContentListSectionLabel where Mark == EmptyView {
    init(title: String, count: Int? = nil) { self.init(title: title, count: count) { EmptyView() } }
}

extension View {
    /// A content list row: hover fill, and a hairline above it unless it opens its section.
    func contentListRow(first: Bool) -> some View {
        ambHoverRow(radius: Amb.radiusControl)
            .overlay(alignment: .top) {
                if !first {
                    Rectangle().fill(Amb.border).frame(height: 1)
                        .padding(.leading, Amb.ListLayout.leading).padding(.trailing, Amb.ListLayout.trailing)
                        .accessibilityHidden(true)
                }
            }
    }
}
