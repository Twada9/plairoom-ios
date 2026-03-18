//
//  ContentRepository.swift
//  PLAIROOM-iOS
//

import Dependencies
import Foundation
internal import PostgREST
import Supabase

// MARK: - ContentRepository

struct ContentRepository: Sendable {
    /// ルームのコンテンツ一覧取得（image_contents / music_contents）
    var fetchContents: @Sendable (_ roomId: String, _ contentType: String) async throws -> [ContentItem]
    /// いいね追加
    var likeContent: @Sendable (_ contentId: String, _ contentType: String) async throws -> Void
    /// いいね削除
    var unlikeContent: @Sendable (_ contentId: String, _ contentType: String) async throws -> Void
    /// 自分がいいね済みか確認
    var isLiked: @Sendable (_ contentId: String, _ contentType: String) async throws -> Bool
    /// コンテンツのステータスを更新（投稿確定 / やり直し）
    var patchStatus: @Sendable (_ contentId: String, _ contentType: String, _ status: ContentStatus) async throws -> Void
}

// MARK: - DependencyKey

private enum ContentRepositoryKey: DependencyKey {
    static var liveValue: ContentRepository {
        let client = DependencyValues._current.supabaseClient
        return ContentRepository(
            fetchContents: { roomId, contentType in
                let table = contentType == "image" ? "image_contents" : "music_contents"
                let dtos: [ContentItemDTO] = try await client
                    .from(table)
                    .select("*,likes(count),profiles(name,avatar_url)")
                    .eq("room_id", value: roomId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                return dtos.map { $0.toEntity() }
            },
            likeContent: { contentId, contentType in
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    throw SupabaseError.unauthorized
                }
                try await client
                    .from("likes")
                    .insert([
                        "user_id": userId,
                        "content_type": contentType,
                        "content_id": contentId
                    ])
                    .execute()
            },
            unlikeContent: { contentId, contentType in
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    throw SupabaseError.unauthorized
                }
                try await client
                    .from("likes")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("content_type", value: contentType)
                    .eq("content_id", value: contentId)
                    .execute()
            },
            isLiked: { contentId, contentType in
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    return false
                }
                let result: [AnyJSON] = try await client
                    .from("likes")
                    .select("id")
                    .eq("user_id", value: userId)
                    .eq("content_type", value: contentType)
                    .eq("content_id", value: contentId)
                    .execute()
                    .value
                return !result.isEmpty
            },
            patchStatus: { contentId, contentType, status in
                let table = contentType == "image" ? "image_contents" : "music_contents"
                try await client
                    .from(table)
                    .update(["status": status.rawValue])
                    .eq("id", value: contentId)
                    .execute()
            }
        )
    }

    static let testValue = ContentRepository(
        fetchContents: { _, _ in [] },
        likeContent: { _, _ in },
        unlikeContent: { _, _ in },
        isLiked: { _, _ in false },
        patchStatus: { _, _, _ in }
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var contentRepository: ContentRepository {
        get { self[ContentRepositoryKey.self] }
        set { self[ContentRepositoryKey.self] = newValue }
    }
}
