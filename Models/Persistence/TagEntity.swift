import SwiftData
import Foundation

/// Overlapping, many-to-many labels (spec 4.2, 7.1), unlike the single
/// optional folder a purchase can belong to.
@Model
final class TagEntity {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var name: String
    var createdAt: Date
    var syncStateRaw: String

    init(
        id: UUID = UUID(), workspaceID: UUID, name: String,
        createdAt: Date = Date(), syncStateRaw: String = "localOnly"
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.name = name
        self.createdAt = createdAt
        self.syncStateRaw = syncStateRaw
    }
}
