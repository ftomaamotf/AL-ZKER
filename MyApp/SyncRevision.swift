import Foundation

struct SyncRevision {
    let timestamp: Double
    let origin: String

    func isNewer(than other: SyncRevision) -> Bool {
        timestamp > other.timestamp || (timestamp == other.timestamp && origin > other.origin)
    }
}
