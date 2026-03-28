//
//  ContentRepository.swift
//  PLAIROOM-iOS
//

import Dependencies
import Foundation
internal import PostgREST
import Supabase

// MARK: - ContentType

enum ContentType: String, Sendable, Codable {
    case image
    case music

    var tableName: String {
        switch self {
        case .image: return "image_contents"
        case .music: return "music_contents"
        }
    }
}

// MARK: - ContentError

enum ContentError: Error {
    case invalidContentType(String)
}

// MARK: - ContentRepository

struct ContentRepository: Sendable {
    /// ルームのコンテンツ一覧取得（image_contents / music_contents）
    var fetchContents: @Sendable (_ roomId: String, _ contentType: ContentType) async throws -> [ContentItem]
    /// いいね追加
    var likeContent: @Sendable (_ contentId: String, _ contentType: ContentType) async throws -> Void
    /// いいね削除
    var unlikeContent: @Sendable (_ contentId: String, _ contentType: ContentType) async throws -> Void
    /// 自分がいいね済みか確認
    var isLiked: @Sendable (_ contentId: String, _ contentType: ContentType) async throws -> Bool
    /// コンテンツのステータスを更新（投稿確定 / やり直し）
    var patchStatus: @Sendable (_ contentId: String, _ contentType: ContentType, _ status: ContentStatus) async throws -> Void
}

// MARK: - DependencyKey

private enum ContentRepositoryKey: DependencyKey {
    static var liveValue: ContentRepository {
        return ContentRepository(
            fetchContents: { roomId, contentType in
                @Dependency(\.supabaseClient) var client: SupabaseClient

                // コンテンツ一覧取得（プロフィール情報を含む）
                let dtos: [ContentItemDTO] = try await client
                    .from(contentType.tableName)
                    .select("*,profiles(name,avatar_url)")
                    .eq("room_id", value: roomId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                // 各コンテンツのいいね数を取得
                var items = dtos.map { $0.toEntity() }
                for i in items.indices {
                    let count = try await client
                        .from("likes")
                        .select("id", head: false, count: .exact)
                        .eq("content_type", value: contentType.rawValue)
                        .eq("content_id", value: items[i].id)
                        .execute()
                        .count ?? 0

                    let item = items[i]
                    items[i] = ContentItem(
                        id: item.id,
                        userId: item.userId,
                        roomId: item.roomId,
                        fileUrl: item.fileUrl,
                        promptUsed: item.promptUsed,
                        status: item.status,
                        createdAt: item.createdAt,
                        likeCount: count,
                        authorName: item.authorName,
                        authorAvatarUrl: item.authorAvatarUrl,
                        duration: item.duration
                    )
                }

                return items
            },
            likeContent: { contentId, contentType in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    throw SupabaseError.unauthorized
                }
                try await client
                    .from("likes")
                    .insert([
                        "user_id": userId,
                        "content_type": contentType.rawValue,
                        "content_id": contentId
                    ])
                    .execute()
            },
            unlikeContent: { contentId, contentType in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    throw SupabaseError.unauthorized
                }
                try await client
                    .from("likes")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("content_type", value: contentType.rawValue)
                    .eq("content_id", value: contentId)
                    .execute()
            },
            isLiked: { contentId, contentType in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    return false
                }
                let result: [AnyJSON] = try await client
                    .from("likes")
                    .select("id")
                    .eq("user_id", value: userId)
                    .eq("content_type", value: contentType.rawValue)
                    .eq("content_id", value: contentId)
                    .execute()
                    .value
                return !result.isEmpty
            },
            patchStatus: { contentId, contentType, status in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                try await client
                    .from(contentType.tableName)
                    .update(["status": status.rawValue])
                    .eq("id", value: contentId)
                    .execute()
            }
        )
    }

    static let testValue = ContentRepository(
        fetchContents: unimplemented(),
        likeContent: unimplemented(),
        unlikeContent: unimplemented(),
        isLiked: unimplemented(),
        patchStatus: unimplemented()
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var contentRepository: ContentRepository {
        get { self[ContentRepositoryKey.self] }
        set { self[ContentRepositoryKey.self] = newValue }
    }
}
