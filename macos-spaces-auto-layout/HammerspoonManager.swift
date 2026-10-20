//
//  HammerspoonManager.swift
//  macos-spaces-auto-layout
//
//  Created by Lucas Pinheiro on 02/04/26.
//

import Foundation

final class HammerspoonManager {

    static let shared = HammerspoonManager()
    private init() {}

    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hammerspoon/layouts_generated.lua")
    }

    // MARK: - Public entry point

    func syncLayouts(_ layouts: [Layout]) {
        let lua = generateLua(from: layouts)
        do {
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try lua.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            print("[HammerspoonManager] Write error: \(error)")
        }
        reloadHammerspoon()
    }

    // MARK: - Lua generator

    func generateLua(from layouts: [Layout]) -> String {
        var lines = ["local M = {}", "", "M.layouts = {"]
        for (i, layout) in layouts.enumerated() {
            lines.append("  [\(i + 1)] = {")
            lines.append("    label = \"\(esc(layout.name))\",")
            lines.append("    isActive = \(layout.isActive ? "true" : "false"),")
            lines.append("    screenMap = {")
            for (j, monitor) in layout.monitors.enumerated() {
                let apps = monitor.apps.map { "\"" + esc($0.name) + "\"" }.joined(separator: ", ")
                lines.append("      [\(j + 1)] = { name = \"\(esc(monitor.name))\", role = \"\(monitor.role.rawValue)\", apps = { \(apps) } },")
            }
            lines.append("    },")
            lines.append("  },")
        }
        lines += ["}", "", "return M", ""]
        return lines.joined(separator: "\n")
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Lua parser

    /// Returns layouts loaded from disk, or nil if the file doesn't exist / can't be parsed.
    func loadLayouts() -> [Layout]? {
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: "\n")

        var layouts: [Layout] = []
        var currentLayoutName: String?
        var currentIsActive = false
        var currentMonitors: [MonitorConfig] = []
        var currentMonitorName: String?
        var currentMonitorRole: MonitorRole = .primary
        var inScreenMap = false

        let labelRe     = try! NSRegularExpression(pattern: #"label\s*=\s*"([^"]*)""#)
        let isActiveRe  = try! NSRegularExpression(pattern: #"isActive\s*=\s*(true|false)"#)
        let screenMapRe = try! NSRegularExpression(pattern: #"screenMap\s*="#)
        let monitorRe   = try! NSRegularExpression(pattern: #"name\s*=\s*"([^"]*)",\s*role\s*=\s*"([^"]*)""#)
        let appsRe      = try! NSRegularExpression(pattern: #"apps\s*=\s*\{([^}]*)\}"#)

        func extractFirst(_ re: NSRegularExpression, in line: String) -> [String]? {
            let r = NSRange(line.startIndex..., in: line)
            guard let m = re.firstMatch(in: line, range: r) else { return nil }
            return (1..<m.numberOfRanges).compactMap {
                Range(m.range(at: $0), in: line).map { String(line[$0]) }
            }
        }

        func flush() {
            guard let name = currentLayoutName else { return }
            layouts.append(Layout(name: name, monitors: currentMonitors, isActive: currentIsActive))
            currentMonitors = []
            currentIsActive = false
        }

        for line in lines {
            if let g = extractFirst(labelRe, in: line) {
                flush()
                currentLayoutName = g[0]
                inScreenMap = false
            } else if let g = extractFirst(isActiveRe, in: line), !inScreenMap {
                currentIsActive = g[0] == "true"
            } else if extractFirst(screenMapRe, in: line) != nil {
                inScreenMap = true
            } else if inScreenMap, let g = extractFirst(monitorRe, in: line) {
                currentMonitorName = g[0]
                currentMonitorRole = g[1] == "PRIMARY" ? .primary : .extended
                if let ag = extractFirst(appsRe, in: line), let mName = currentMonitorName {
                    currentMonitors.append(MonitorConfig(name: mName, role: currentMonitorRole, apps: parseApps(ag[0])))
                    currentMonitorName = nil
                }
            } else if inScreenMap, currentMonitorName != nil, let ag = extractFirst(appsRe, in: line) {
                if let mName = currentMonitorName {
                    currentMonitors.append(MonitorConfig(name: mName, role: currentMonitorRole, apps: parseApps(ag[0])))
                    currentMonitorName = nil
                }
            }
        }
        flush()

        return layouts.isEmpty ? nil : layouts
    }

    private func parseApps(_ raw: String) -> [AppEntry] {
        let pattern = try! NSRegularExpression(pattern: #""([^"]*)""#)
        let r = NSRange(raw.startIndex..., in: raw)
        return pattern.matches(in: raw, range: r).compactMap {
            Range($0.range(at: 1), in: raw).map { AppEntry(name: String(raw[$0])) }
        }
    }

    // MARK: - AppleScript reloader

    private func reloadHammerspoon() {
        let src = #"tell application "Hammerspoon" to execute lua code "hs.reload()""#
        guard let script = NSAppleScript(source: src) else { return }
        var err: NSDictionary?
        script.executeAndReturnError(&err)
        if let err = err { print("[HammerspoonManager] AppleScript error: \(err)") }
    }
}
