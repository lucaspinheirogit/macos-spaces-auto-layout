import Foundation
import OSLog
import Observation

/// Holds the user's setups and saves every change to disk.
@Observable
final class DeskSetupStore {
    private(set) var setups: [DeskSetup]

    /// Set when saving would destroy data the store couldn't load. Every `update(_:)` then throws.
    private(set) var savingBlockedReason: SavingBlockedReason?

    var isSavingBlocked: Bool { savingBlockedReason != nil }

    @ObservationIgnored private let storage: DeskSetupFileStorage
    @ObservationIgnored private let logger = Logger(subsystem: AppIdentity.bundleIdentifier, category: "DeskSetupStore")

    init(storage: DeskSetupFileStorage = .default) {
        self.storage = storage
        let path = storage.fileURL.path
        do {
            guard var file = try storage.load() else {
                setups = DeskSetup.firstLaunchSetups
                return
            }
            let repaired = file.repairDuplicateIds()
            if repaired > 0 {
                logger.notice("Replaced \(repaired) duplicate ids in \(path, privacy: .public)")
            }
            setups = file.setups
            if file.schemaVersion > DeskSetupFile.currentSchemaVersion {
                logger.error(
                    "\(path, privacy: .public) has schema version \(file.schemaVersion), newer than \(DeskSetupFile.currentSchemaVersion). Loaded read-only"
                )
                savingBlockedReason = .newerSchemaVersion(file.schemaVersion)
            }
        } catch let error as DeskSetupFile.NewerSchemaVersionError {
            logger.error(
                "\(path, privacy: .public) has schema version \(error.schemaVersion), which this version can't read")
            setups = DeskSetup.firstLaunchSetups
            savingBlockedReason = .newerSchemaVersion(error.schemaVersion)
        } catch let error as DecodingError {
            logger.error("Could not decode \(path, privacy: .public): \(error)")
            setups = DeskSetup.firstLaunchSetups
            // Keep the unreadable file so saving the first-launch setups doesn't destroy the user's data.
            do {
                let backupURL = try storage.moveAsideUnreadableFile()
                logger.notice("Moved unreadable setups file to \(backupURL.path, privacy: .public)")
            } catch {
                logger.error("Could not move unreadable setups file aside, so saving is blocked: \(error)")
                savingBlockedReason = .couldNotMoveAside(path: path)
            }
        } catch {
            logger.error("Could not read \(path, privacy: .public), so saving is blocked: \(error)")
            setups = DeskSetup.firstLaunchSetups
            savingBlockedReason = .unreadableFile(path: path)
        }
    }

    /// Replaces the setup with the same id and saves. Unknown ids are ignored.
    /// Throws when saving is blocked or the write fails; the in-memory setups are then unchanged.
    func update(_ setup: DeskSetup) throws(DeskSetupStoreError) {
        if let savingBlockedReason { throw .savingBlocked(savingBlockedReason) }
        guard let index = setups.firstIndex(where: { $0.id == setup.id }) else { return }
        var updated = setups
        updated[index] = setup
        do {
            try storage.save(updated)
        } catch {
            logger.error("Could not save setups: \(error)")
            throw .writeFailed(error.localizedDescription)
        }
        setups = updated
    }
}

/// Why `DeskSetupStore` refuses to save.
nonisolated enum SavingBlockedReason: Equatable, Sendable {
    /// The file was written by a newer version of the app. It's shown read-only so this version can't downgrade it.
    case newerSchemaVersion(Int)
    /// The file exists but couldn't be read (for example it's a folder, or permissions deny it).
    case unreadableFile(path: String)
    /// The file couldn't be decoded, and moving it aside failed.
    case couldNotMoveAside(path: String)

    var message: String {
        switch self {
        case .newerSchemaVersion:
            "Your setups were saved by a newer version of this app. Update the app to make changes."
        case .unreadableFile(let path):
            "The setups file at \(path) can't be read. Changes won't be saved, so it isn't overwritten."
        case .couldNotMoveAside(let path):
            "The setups file at \(path) is damaged and couldn't be moved aside. Changes won't be saved, so it isn't overwritten."
        }
    }
}

nonisolated enum DeskSetupStoreError: LocalizedError, Equatable {
    case savingBlocked(SavingBlockedReason)
    /// The write failed. Holds the underlying error's description.
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .savingBlocked(let reason): reason.message
        case .writeFailed(let description): "The setups couldn't be saved. \(description)"
        }
    }
}
