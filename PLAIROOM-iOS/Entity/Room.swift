//
//  Room.swift
//  PLAIROOM-iOS
//

import Foundation

/// ルームエンティティ
struct Room: Equatable, Identifiable, Decodable, Sendable {
    let id: String
    let title: String
    let description: String
    let basePrompt: String
    let roomType: String
    /// "image" または "music"
    let contentType: String
    let createdAt: String
}
