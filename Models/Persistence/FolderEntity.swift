import SwiftData
import Foundation

/// Optional single-level-or-shallow hierarchy (spec 4.2, 7.1). Deliberately
/// secondary to Purpose in the information architecture - see CLAUDE.md
/// section 1: folders are a human filing convenience, not how evidence is
/// actually organized.
@Model
final class FolderEntity {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var parentID: UUID?
    var name: String
    var createdAt: Date
    var syncStateRaw: String

    init(
        id: UUID = UUID(), workspaceID: UUID, parentID: UUID? = nil, name: String,
        createdAt: Date = Date(), syncStateRaw: String = "localOnly"
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.parentID = parentID
        self.name = name
        self.createdAt = createdAt
        self.syncStateRaw = syncStateRaw
    }
}
