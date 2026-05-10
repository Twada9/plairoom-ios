//
//  ContentItemDTO.swift
//  PLAIROOM-iOS
//

import Foundation

/// image_contents / music_contents テーブルの Supabase レスポンス DTO
nonisolated struct ContentItemDTO: Decodable, Sendable {
    let id: String
    let userId: String
    let roomId: String
    let fileUrl: String?
    let promptUsed: String?
    let status: String
    let createdAt: String
    let profiles: ProfileDTO?
    /// music_contents のみ
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case roomId = "room_id"
        case fileUrl = "file_url"
        case promptUsed = "prompt_used"
        case status
        case createdAt = "created_at"
        case profiles
        case duration
    }

    func toEntity(likeCount: Int) -> ContentItem {
        ContentItem(
            id: id,
            userId: userId,
            roomId: roomId,
            fileUrl: fileUrl,
            promptUsed: promptUsed,
            status: ContentStatus(rawValue: status) ?? .failed,
            createdAt: createdAt,
            likeCount: likeCount,
            authorName: profiles?.name,
            authorAvatarUrl: profiles?.avatarUrl,
            duration: duration
        )
    }
}

nonisolated struct LikeContentIdDTO: Decodable, Sendable {
    let contentId: String

    enum CodingKeys: String, CodingKey {
        case contentId = "content_id"
    }
}

nonisolated struct ProfileDTO: Decodable, Sendable {
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarUrl = "avatar_url"
    }
}
