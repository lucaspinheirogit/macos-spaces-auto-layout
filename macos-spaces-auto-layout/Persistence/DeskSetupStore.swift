import Foundation
import OSLog
import Observation

/// Holds the user's setups and saves every change to disk.
@Observable
final class DeskSetupStore {
    private(set) var setups: [DeskSetup]

    @ObservationIgnored private let storage: DeskSetupFileStorage
    @ObservationIgnored private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "DeskSetupStore")

    init(storage: DeskSetupFileStorage = .default) {
        self.storage = storage
        do {
            setups = try storage.load() ?? DeskSetup.firstLaunchSetups
        } catch {
            logger.error("Could not read \(storage.fileURL.path, privacy: .public): \(error)")
            setups = DeskSetup.firstLaunchSetups
            // Keep the unreadable file so saving the first-launch setups doesn't destroy the user's data.
            do {
                let backupURL = try storage.moveAsideUnreadableFile()
                logger.notice("Moved unreadable setups file to \(backupURL.path, privacy: .public)")
            } catch {
                logger.error("Could not move unreadable setups file aside: \(error)")
            }
        }
    }

    /// Replaces the setup with the same id and saves. Unknown ids are ignored.
    func update(_ setup: DeskSetup) {
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
