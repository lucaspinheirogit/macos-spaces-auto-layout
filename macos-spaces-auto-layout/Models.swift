//
//  Models.swift
//  macos-spaces-auto-layout
//
//  Created by Lucas Pinheiro on 02/04/26.
//

import Foundation
import Combine

struct AppEntry: Identifiable {
    let id = UUID()
    var name: String
    var bundleId: String?   // e.g. "com.tinyspeck.slackmacgap"
}

enum MonitorRole: String {
    case primary = "PRIMARY"
    case extended = "EXTENDED"
}

struct MonitorConfig: Identifiable {
    let id = UUID()
    var name: String
    var role: MonitorRole
    var apps: [AppEntry]
}

class Layout: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var monitors: [MonitorConfig]
    @Published var isActive: Bool

    var monitorCount: Int { monitors.count }

    var icon: String {
        switch monitorCount {
        case 1: return "rectangle"
        case 2: return "rectangle.split.2x1"
        default: return "rectangle.split.3x1"
        }
    }

    init(name: String, monitors: [MonitorConfig], isActive: Bool = false) {
        self.name = name
        self.monitors = monitors
        self.isActive = isActive
    }
}

class LayoutStore: ObservableObject {
    @Published var layouts: [Layout]

    init() {
        layouts = [
            Layout(
                name: "Single Monitor",
                monitors: [
                    MonitorConfig(name: "Monitor 1", role: .primary, apps: [])
                ],
                isActive: false
            ),
            Layout(
                name: "Dual Monitor",
                monitors: [
                    MonitorConfig(name: "Monitor 1", role: .primary, apps: []),
                    MonitorConfig(name: "Monitor 2", role: .extended, apps: [])
                ],
                isActive: false
            ),
            Layout(
                name: "Triple Monitor",
                monitors: [
                    MonitorConfig(name: "Monitor 1", role: .primary, apps: []),
                    MonitorConfig(name: "Monitor 2", role: .extended, apps: []),
                    MonitorConfig(name: "Monitor 3", role: .extended, apps: [])
                ],
                isActive: false
            )
        ]
    }

    func activate(_ layout: Layout) {
        for l in layouts {
            l.isActive = (l.id == layout.id)
        }
        objectWillChange.send()
    }
}
