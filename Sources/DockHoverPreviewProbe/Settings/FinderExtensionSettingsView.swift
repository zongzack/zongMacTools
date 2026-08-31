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
    @State private var editingExtensionItemID: String?
    @State private var draftExtension = ""
    @State private var isImporting = false
    @State private var pendingDeleteItem: FinderNewFileCatalogItem?
    @State private var isConfirmingRestore = false
    @State private var importFailureMessage: String?
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
                    Text(text.string(.finderNewFileInteractionHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button(text.string(.finderNewFileImport)) { isImporting = true }
                        Spacer()
                        Button(text.string(.finderNewFileRestoreDefaults)) { isConfirmingRestore = true }
                    }
                    HStack(spacing: 12) {
                        Text("")
                            .frame(width: 18)
                        Text("")
                            .frame(width: 24)
                        Text(text.string(.finderNewFileFormatName))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(text.string(.finderNewFileFormatExtension))
                            .frame(width: 90, alignment: .leading)
                        Text(text.string(.finderNewFileFormatEnabled))
                            .frame(width: 90, alignment: .center)
                        Text("")
                            .frame(width: 34)
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                let importResult = viewModel.importTemplates(from: urls, textProvider: text)
                if !importResult.failures.isEmpty {
                    importFailureMessage = importResult.failures.map { "\($0.fileName): \($0.reason)" }.joined(separator: "\n")
                }
            }
        }
        .alert(text.string(.finderNewFileImportResult), isPresented: Binding(
            get: { importFailureMessage != nil },
            set: { if !$0 { importFailureMessage = nil } }
        )) {
            Button(text.string(.finderNewFileDone), role: .cancel) { importFailureMessage = nil }
        } message: {
            Text(importFailureMessage ?? "")
        }
        .alert(text.string(.finderNewFileDeleteConfirmationTitle), isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { if !$0 { pendingDeleteItem = nil } }
        ), presenting: pendingDeleteItem) { item in
            Button(text.string(.finderNewFileDeleteTemplate), role: .destructive) {
                _ = viewModel.deleteCustomItem(withID: item.id, confirmed: true)
                pendingDeleteItem = nil
            }
            Button(text.string(.finderNewFileCancel), role: .cancel) { pendingDeleteItem = nil }
        } message: { item in
            Text("\(text.string(.finderNewFileDeleteConfirmationMessage)) \(item.displayName)")
        }
        .alert(text.string(.finderNewFileRestoreConfirmationTitle), isPresented: $isConfirmingRestore) {
            Button(text.string(.finderNewFileConfirm), role: .destructive) { _ = viewModel.restoreDefaults(confirmed: true) }
            Button(text.string(.finderNewFileCancel), role: .cancel) {}
        } message: {
            Text(text.string(.finderNewFileRestoreConfirmationMessage))
        }
    }

    @ViewBuilder
    private func formatRow(_ item: FinderNewFileCatalogItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 24)
                .contentShape(Rectangle())
                .help(text.string(.finderNewFileInteractionHint))

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

            Group {
                if editingExtensionItemID == item.id, item.source == .custom {
                    TextField(".\(item.fileExtension)", text: $draftExtension)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { finishEditingExtension(item) }
                        .onExitCommand { cancelEditingExtension() }
                } else {
                    Text(".\(item.fileExtension)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            guard item.source == .custom else { return }
                            editingExtensionItemID = item.id
                            draftExtension = item.fileExtension
                        }
                }
            }
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

            if item.source == .custom {
                Button {
                    pendingDeleteItem = item
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help(text.string(.finderNewFileDeleteTemplate))
                .accessibilityLabel(text.string(.finderNewFileDeleteTemplate))
            } else {
                Image(systemName: "lock")
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .help(text.string(.finderNewFileFormatExtension))
                    .accessibilityLabel(text.string(.finderNewFileFormatExtension))
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Text(".\(item.fileExtension)")
            if item.source == .builtIn {
                Text(text.string(.finderNewFileFormatExtension))
                    .foregroundStyle(.secondary)
            } else {
                Button(text.string(.finderNewFileDeleteTemplate), role: .destructive) { pendingDeleteItem = item }
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

    private func finishEditingExtension(_ item: FinderNewFileCatalogItem) {
        if viewModel.updateFileExtension(draftExtension, for: item.id) {
            editingExtensionItemID = nil
        } else {
            draftExtension = item.fileExtension
        }
    }

    private func cancelEditingExtension() {
        editingExtensionItemID = nil
        draftExtension = ""
    }

    private func fileTypeIcon(for fileExtension: String) -> Image {
        let type = UTType(filenameExtension: fileExtension) ?? .data
        return Image(nsImage: NSWorkspace.shared.icon(for: type))
    }
}
