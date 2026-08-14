import SwiftUI

enum TagFilterMode: String { case include, exclude }
enum TagMatchMode: String { case any, all }

/// Reusable "filter by tags" control: include/exclude + any/all mode toggles plus a wrapping
/// row of tappable tag chips. Shared by the vocabulary test and writing practice setup screens.
struct TagFilterBar: View {
    let availableTags: [String]
    @Binding var selectedTags: Set<String>
    @Binding var filterMode: TagFilterMode
    @Binding var matchMode: TagMatchMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Filter by tags")
                Spacer()
                if !selectedTags.isEmpty {
                    Button("Clear") { selectedTags.removeAll() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                modeToggle("Include", isOn: filterMode == .include) { filterMode = .include }
                modeToggle("Exclude", isOn: filterMode == .exclude) { filterMode = .exclude }
                Divider().frame(height: 14)
                modeToggle("Any", isOn: matchMode == .any) { matchMode = .any }
                modeToggle("All", isOn: matchMode == .all) { matchMode = .all }
            }

            if availableTags.isEmpty {
                Text("No tags in this word list yet").font(.caption).foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(availableTags, id: \.self) { tag in
                        Button(tag) { toggle(tag) }
                            .buttonStyle(ChipToggleStyle(isSelected: selectedTags.contains(tag)))
                    }
                }
            }

            if !selectedTags.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.brandIndigo.opacity(0.08)))
            }
        }
    }

    private var summary: String {
        let joined = selectedTags.sorted().joined(separator: ", ")
        switch (filterMode, matchMode) {
        case (.include, .any): return "Words with any of: \(joined)"
        case (.include, .all): return "Words with all of: \(joined)"
        case (.exclude, .any): return "Excluding words with any of: \(joined)"
        case (.exclude, .all): return "Excluding words with all of: \(joined)"
        }
    }

    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    private func modeToggle(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOn ? .white : Color.brandIndigo)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(isOn ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Color.brandIndigo.opacity(0.1))))
        }
        .buttonStyle(.plain)
    }
}

/// Applies a tag filter (include/exclude, any/all) to a collection, keyed by a tag-string extractor.
func applyTagFilter<T>(_ items: [T], tags: (T) -> [String], selected: Set<String>, mode: TagFilterMode, match: TagMatchMode) -> [T] {
    guard !selected.isEmpty else { return items }
    let selectedLower = Set(selected.map { $0.lowercased() })
    return items.filter { item in
        let itemTags = Set(tags(item).map { $0.lowercased() })
        let matched = match == .all ? selectedLower.isSubset(of: itemTags) : !selectedLower.isDisjoint(with: itemTags)
        return mode == .exclude ? !matched : matched
    }
}
