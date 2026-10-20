//
//  SetupStore.swift
//  macos-spaces-auto-layout
//

import Foundation
import Observation
import OSLog

/// Holds the user's setups and saves every change to disk.
@Observable
final class SetupStore {
    private(set) var setups: [Setup]

    @ObservationIgnored private let storage: SetupFileStorage
    @ObservationIgnored private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "SetupStore")

    init(storage: SetupFileStorage = .default) {
        self.storage = storage
        do {
            setups = try storage.load() ?? Setup.defaults
        } catch {
            logger.error("Could not read \(storage.fileURL.path, privacy: .public): \(error)")
            setups = Setup.defaults
            // Keep the unreadable file so saving the defaults doesn't destroy the user's data.
            do {
                let backupURL = try storage.moveAsideUnreadableFile()
                logger.notice("Moved unreadable setups file to \(backupURL.path, privacy: .public)")
            } catch {
                logger.error("Could not move unreadable setups file aside: \(error)")
            }
        }
    }

    /// Replaces the setup with the same id and saves. Unknown ids are ignored.
    func update(_ setup: Setup) {
        guard let index = setups.firstIndex(where: { $0.id == setup.id }) else { return }
        setups[index] = setup
        save()
    }

    private func save() {
        do {
            try storage.save(setups)
        } catch {
            logger.error("Could not save setups: \(error)")
        }
    }
}
