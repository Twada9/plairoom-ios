//
//  Room.swift
//  PLAIROOM-iOS
//

import Foundation

/// ルームエンティティ
struct Room: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let basePrompt: String
    let roomType: String
    let contentType: ContentType
    let createdAt: String
}
