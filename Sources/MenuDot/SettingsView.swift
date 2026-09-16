import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Two bars. One click.").font(.title2.weight(.semibold))
                    Text("Click the menu bar dot to switch between Main and Secondary.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack {
                Circle().fill(model.active ? Color.green : Color.secondary).frame(width: 7, height: 7)
                Text(model.status).font(.callout)
                Spacer()
                if model.active {
                    Button(model.revealed ? "Switch to Main" : "Switch to Secondary") { model.toggle() }
                }
            }
            if !model.available {
                Text("Switching is unavailable on this macOS build.").foregroundStyle(.red)
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("New menu bar icons")
                    Text("Existing choices stay where they are.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Default for new menu bar icons", selection: Binding(
                    get: { model.defaultGroup }, set: { model.setDefault($0) }
                )) {
                    ForEach(Visibility.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 160)
            }
            if !model.accessibilityAllowed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detect actual menu bar icons").font(.headline)
                    Text("Accessibility access lets Menu Dot identify icons in the menu bar, instead of listing every running process. Saved groups still work without this access. Detection reads icon owners and labels, not your documents.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Detect menu bar icons…") { model.requestDiscoveryAccess() }
                }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else if let message = model.discoveryMessage {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a menu bar icon", text: $model.search).textFieldStyle(.plain)
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).help("Clear search")
                }
                Button(model.scanning ? "Scanning…" : "Refresh") { model.refreshApps() }
                    .disabled(model.scanning)
            }.padding(9).background(.background, in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let confirmed = model.apps.filter { $0.confirmed && matches($0.name) }
                    if confirmed.isEmpty {
                        Text(model.accessibilityAllowed ? "No menu bar icons detected yet." : "Your detected icons will appear here.")
                            .foregroundStyle(.secondary).padding(.vertical, 24)
                    }
                    ForEach(confirmed) { row($0) }
                    let previous = model.apps.filter { !$0.confirmed && matches($0.name) }
                    if !previous.isEmpty {
                        DisclosureGroup("Earlier choices · not verified as menu bar icons (\(previous.count))") {
                            ForEach(previous) { row($0) }
                        }.font(.callout).padding(.vertical, 12)
                    }
                }.padding(.horizontal, 14).padding(.bottom, 8)
            }.background(.background, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text("Both keeps an icon on Main and Secondary. Always hidden appears in neither. Right-click the menu bar dot for Settings or Restore all icons.")
                Text("Icons from the same app move together. App artwork identifies the owner; it may differ from its menu bar icon. Clock and Control Center stay visible and cannot be assigned to a group.")
                Text("macOS 27 may hide additional Apple controls while switching is active. Restore all icons releases the session.")
            }.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Restore all icons") { model.restore() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!model.active && !model.applying)
                Spacer()
                if model.active {
                    Text("Choices save automatically").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Start switching") { model.start() }.buttonStyle(.borderedProminent)
                        .disabled(!model.available || model.scanning || !model.apps.contains(where: \.confirmed))
                }
            }
        }.padding(22).frame(minWidth: 620, minHeight: 680)
    }

    private func matches(_ value: String) -> Bool {
        model.search.isEmpty || value.localizedCaseInsensitiveContains(model.search)
    }

    private func row(_ app: AppEntry) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 24, height: 24)
                } else {
                    Image(systemName: app.id.hasPrefix("system:") ? "menubar.rectangle" : "app").frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).lineLimit(1).help(app.id)
                    Text(app.detected ? app.detail : (app.confirmed ? "Saved icon · not currently detected" : app.detail))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).help(app.detail)
                }
                Spacer(minLength: 12)
                Picker("Group for \(app.name)", selection: Binding(
                    get: { model.rules.assignments[app.id, default: .visible] },
                    set: { model.set($0, for: app.id) }
                )) {
                    ForEach(Visibility.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 150)
            }.padding(.vertical, 9)
            Divider()
        }
    }
}
