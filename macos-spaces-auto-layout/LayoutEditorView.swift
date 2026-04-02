//
//  LayoutEditorView.swift
//  macos-spaces-auto-layout
//
//  Created by Lucas Pinheiro on 02/04/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LayoutEditorView: View {
    @ObservedObject var layout: Layout
    @Environment(\.dismiss) private var dismiss

    // Local editing copy — Cancel discards, Save commits
    @State private var layoutName: String
    @State private var monitors: [MonitorConfig]

    init(layout: Layout) {
        self.layout = layout
        _layoutName = State(initialValue: layout.name)
        _monitors = State(initialValue: layout.monitors)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + Monitor columns in the same container
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    TextField("Layout name", text: $layoutName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                    Text("\(layout.monitorCount) Monitor\(layout.monitorCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                HStack(alignment: .top, spacing: 16) {
                    ForEach($monitors) { $monitor in
                        MonitorColumnView(monitor: $monitor)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    layout.name = layoutName
                    layout.monitors = monitors
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .fixedSize()
        .background(Color(.underPageBackgroundColor))
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
    }
}

struct MonitorColumnView: View {
    @Binding var monitor: MonitorConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(Color.accentColor)
                Text(monitor.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(monitor.role.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // App list
            VStack(spacing: 0) {
                ForEach(monitor.apps) { app in
                    AppRowView(app: app)
                    if app.id != monitor.apps.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }

            // Add App button
            Button {
                pickApp { entry in
                    if let entry { monitor.apps.append(entry) }
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("Add App")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .background(Color(.windowBackgroundColor).opacity(0.5))
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(minWidth: 200)
    }

    private func pickApp(completion: @escaping (AppEntry?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Select"
        panel.message = "Choose an application to add"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }

            let plistURL = url.appendingPathComponent("Contents/Info.plist")
            var name = url.deletingPathExtension().lastPathComponent
            var bundleId: String? = nil

            if let data = try? Data(contentsOf: plistURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                name = plist["CFBundleDisplayName"] as? String
                    ?? plist["CFBundleName"] as? String
                    ?? name
                bundleId = plist["CFBundleIdentifier"] as? String
            }

            completion(AppEntry(name: name, bundleId: bundleId))
        }
    }
}

struct AppRowView: View {
    let app: AppEntry

    private var appIcon: NSImage {
        if let bundleId = app.bundleId,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(forFileType: "app")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
            Text(app.name)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    LayoutEditorView(layout: LayoutStore().layouts[1])
}
