import SwiftUI

struct SwitcherView: View {
    @ObservedObject var controller: SwitcherController

    private static let rowHeight: CGFloat = 30
    private static let sectionHeaderHeight: CGFloat = 27
    private static let outerPadding: CGFloat = 6
    private static let maxVisibleRows = 20

    var body: some View {
        VStack(spacing: 0) {
            if case .filter = controller.state {
                filterField
                Divider()
            }
            list
        }
        .padding(.vertical, Self.outerPadding)
        .frame(width: SwitcherPanel.fixedWidth)
        // glassEffect draws the Liquid Glass behind the content; the matching
        // clipShape keeps the selected-row highlight inside the rounded corners.
        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filterField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(controller.filter.isEmpty ? "Filter…" : controller.filter)
                .foregroundStyle(controller.filter.isEmpty ? .secondary : .primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .font(.system(.body, design: .monospaced))
    }

    private var list: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(grouped) { group in
                        if shouldShowSectionHeader(group.section) {
                            sectionHeader(group.section)
                        }
                        ForEach(group.rows) { row in
                            rowView(row, selected: row.id == selectedID)
                                .id(row.id)
                                .onTapGesture { controller.activate(rowID: row.id) }
                                .onHover { if $0 { controller.hover(rowID: row.id) } }
                        }
                    }
                }
            }
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    scrollProxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        .frame(height: listHeight)
    }

    /// Height the list view should occupy: tight to content when below the cap,
    /// fixed at the 20-row cap when there's more (so the ScrollView scrolls).
    /// Always at least one row's worth so an empty list still has a visible area.
    private var listHeight: CGFloat {
        let rows = CGFloat(min(controller.rows.count, Self.maxVisibleRows)) * Self.rowHeight
        let headers = CGFloat(grouped.count { shouldShowSectionHeader($0.section) }) * Self.sectionHeaderHeight
        return max(Self.rowHeight, rows + headers)
    }

    // MARK: - Grouping for display

    private struct Group: Identifiable {
        let section: WindowSection
        let rows: [WindowEntry]
        var id: WindowSection { section }
    }

    private var grouped: [Group] {
        guard !controller.rows.isEmpty else { return [] }
        return [WindowSection.current, .minimized, .hidden].compactMap { section in
            let rows = controller.rows.filter { $0.section == section }
            return rows.isEmpty ? nil : Group(section: section, rows: rows)
        }
    }

    private func shouldShowSectionHeader(_ section: WindowSection) -> Bool {
        // The on-screen section is the implicit default; only call out the others.
        section != .current
    }

    private func sectionHeader(_ section: WindowSection) -> some View {
        // Align the label with the app-name column: same 12pt leading inset and
        // 140pt right-aligned width as the app name in rowView.
        Text(section.label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 140, alignment: .trailing)
            .padding(.leading, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    // MARK: - Row

    private var selectedID: WindowEntry.ID? {
        controller.rows.indices.contains(controller.selection)
            ? controller.rows[controller.selection].id
            : nil
    }

    private func rowView(_ entry: WindowEntry, selected: Bool) -> some View {
        let selectedText = Color(nsColor: .alternateSelectedControlTextColor)
        let titleEmpty = entry.windowTitle.isEmpty
        return HStack(spacing: 8) {
            Text(entry.appName)
                .font(.body)
                .foregroundStyle(selected ? AnyShapeStyle(selectedText.opacity(0.8)) : AnyShapeStyle(.tertiary))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(width: 140, alignment: .trailing)
            Image(nsImage: entry.appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text(titleEmpty ? "(Untitled)" : entry.windowTitle)
                .font(.body)
                .italic(titleEmpty)
                .foregroundStyle(selected ? selectedText : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(selected ? Color(nsColor: .selectedContentBackgroundColor) : .clear)
        .contentShape(Rectangle())
    }
}
