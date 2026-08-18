import SwiftData

/// Single source of truth for the SwiftData schema so the app target and
/// any test target that needs an in-memory container stay in sync.
enum PersistenceSchema {
    static let models: [any PersistentModel.Type] = [
        PurchaseEntity.self,
        ItemEntity.self,
        AttachmentEntity.self,
        WarrantyEntity.self,
        FolderEntity.self,
        TagEntity.self,
        OutboxOperationEntity.self,
    ]

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: Schema(models), configurations: [configuration])
        } catch {
            // A failed on-disk container is unrecoverable without user data
            // loss either way; fail loudly rather than silently degrading
            // to an in-memory container that would quietly lose everything
            // captured during the session.
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}
