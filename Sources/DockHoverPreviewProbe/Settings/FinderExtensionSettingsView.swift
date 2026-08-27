import AppKit
import FinderNewFileCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct FinderExtensionSettingsView: View {
    @ObservedObject var viewModel: FinderExtensionSettingsViewModel
    let text: AppTextProvider
    @State private var editingItemID: String?
    @State private var draftName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        SettingsPageContainer(
            title: text.string(.contextMenuExtension),
            subtitle: text.string(.finderExtensionSubtitle)
        ) {
            SettingsGroup {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.state.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.state.isEnabled ? .green : .secondary)
                    Text(text.string(viewModel.state.isEnabled ? .finderExtensionEnabled : .finderExtensionDisabled))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Divider()

                Button(text.string(.manageFinderExtension)) {
                    viewModel.openManagementInterface()
                }

                Divider()

                SettingsGroup(title: text.string(.finderNewFileFormats)) {
                    HStack(spacing: 12) {
                        Text(text.string(.finderNewFileFormatName))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(text.string(.finderNewFileFormatExtension))
                            .frame(width: 90, alignment: .leading)
                        Text(text.string(.finderNewFileFormatEnabled))
                            .frame(width: 90, alignment: .center)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(viewModel.state.items) { item in
                        formatRow(item)
                            .draggable(item.id)
                            .dropDestination(for: String.self) { droppedIDs, _ in
                                guard let droppedID = droppedIDs.first, droppedID != item.id else { return false }
                                return viewModel.moveItem(withID: droppedID, beforeID: item.id)
                            }
                    }
                    Color.clear
                        .frame(height: 18)
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { droppedIDs, _ in
                            guard let droppedID = droppedIDs.first else { return false }
                            return viewModel.moveItem(withID: droppedID, beforeID: nil)
                        }
                }
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: isNameFieldFocused) { _, isFocused in
            guard !isFocused,
                  let itemID = editingItemID,
                  let item = viewModel.state.items.first(where: { $0.id == itemID })
            else { return }
            finishEditing(item)
        }
    }

    @ViewBuilder
    private func formatRow(_ item: FinderNewFileCatalogItem) -> some View {
        HStack(spacing: 12) {
            fileTypeIcon(for: item.fileExtension)
                .frame(width: 24, height: 24)

            Group {
                if editingItemID == item.id {
                    TextField(item.displayName, text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .onSubmit { finishEditing(item) }
                        .onExitCommand { cancelEditing() }
                } else {
                    Text(item.displayName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingItemID = item.id
                            draftName = item.displayName
                            isNameFieldFocused = true
                        }
                }
            }

            Text(".\(item.fileExtension)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Toggle(
                item.isEnabled ? text.string(.finderNewFileFormatEnabled) : text.string(.finderNewFileFormatDisabled),
                isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ = viewModel.setItemEnabled($0, for: item.id) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .frame(width: 90)
            .help(item.isEnabled ? text.string(.finderNewFileFormatEnabled) : text.string(.finderNewFileFormatDisabled))
        }
        .padding(.vertical, 4)
        .contextMenu {
            Text(".\(item.fileExtension)")
            if item.source == .builtIn {
                Text(text.string(.finderNewFileFormatExtension))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func finishEditing(_ item: FinderNewFileCatalogItem) {
        if viewModel.updateDisplayName(draftName, for: item.id) {
            editingItemID = nil
            isNameFieldFocused = false
        } else {
            draftName = item.displayName
        }
    }

    private func cancelEditing() {
        editingItemID = nil
        draftName = ""
        isNameFieldFocused = false
    }

    private func fileTypeIcon(for fileExtension: String) -> Image {
        let type = UTType(filenameExtension: fileExtension) ?? .data
        return Image(nsImage: NSWorkspace.shared.icon(for: type))
    }
}
