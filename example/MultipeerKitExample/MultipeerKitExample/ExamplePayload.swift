import Foundation

struct ExamplePayload: Hashable, Codable, Identifiable {
    let id: UUID
    let body: String
    let sentAt: Date
}
