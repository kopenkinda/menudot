import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Launch at login")
                Spacer()
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }
                )).labelsHidden().toggleStyle(.switch)
            }
            if model.loginStatus == .requiresApproval {
                Button("Allow in Login Items…") { model.openLoginSettings() }
            }
            if let error = model.loginError {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            HStack {
                Text("Launch state")
                Spacer()
                Picker("Launch state", selection: Binding(
                    get: { model.launchStarted }, set: { model.setLaunchStarted($0) }
                )) {
                    Text("Started").tag(true)
                    Text("Stopped").tag(false)
                }.labelsHidden().pickerStyle(.menu).buttonSizing(.flexible).frame(width: 160)
            }

            if !model.available {
                Text("Switching is unavailable on this macOS build.").foregroundStyle(.red)
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
            }
            HStack {
                Text("New menu bar icons")
                Spacer()
                Picker("Default for new menu bar icons", selection: Binding(
                    get: { model.defaultGroup }, set: { model.setDefault($0) }
                )) {
                    ForEach(Visibility.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.menu).buttonSizing(.flexible).frame(width: 160)
            }
            HStack {
                Text("Icon detection")
                Spacer()
                Picker("Icon detection", selection: Binding(
                    get: { model.discoveryMode }, set: { model.setDiscoveryMode($0) }
                )) {
                    ForEach(DiscoveryMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.menu).buttonSizing(.flexible).frame(width: 160)
                    .help("Battery Saver checks less often for icons added by running apps. Switching bars and Refresh stay immediate.")
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
                }.padding(.horizontal, 14).padding(.bottom, 8)
            }.background(.background, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Spacer()
                if model.active || model.applying {
                    Button("Stop") { model.restore() }
                        .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Button("Start") { model.start() }.buttonStyle(.borderedProminent)
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
                Button {
                    model.removeEntry(app.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(app.name) from the list")
                .help("Forget this icon and its saved group. It will return if detected again.")
            }.padding(.vertical, 9)
            Divider()
        }
    }
}
