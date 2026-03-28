//
//  RoomRepository.swift
//  PLAIROOM-iOS
//

import Dependencies
import Foundation
import Supabase

// MARK: - RoomRepository

/// ルームリポジトリ
///
/// TCA の struct-based dependency パターンで定義。
struct RoomRepository: Sendable {
    /// ルーム一覧を取得
    var fetchRooms: @Sendable () async throws -> [Room]
}

// MARK: - DependencyKey

private enum RoomRepositoryKey: DependencyKey {
    static var liveValue: RoomRepository {
        return RoomRepository(
            fetchRooms: {
                @Dependency(\.supabaseClient) var client
                let data = try await client
                    .from("rooms")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .data
                let dtos = try await JSONDecoder.snakeCaseDecoder.decode([RoomDTO].self, from: data)
                return try dtos.map { dto in
                    let contentType = try ContentType(rawValue: dto.contentType)
                    return Room(
                        id: dto.id,
                        title: dto.title,
                        description: dto.description,
                        basePrompt: dto.basePrompt,
                        roomType: dto.roomType,
                        contentType: contentType!,
                        createdAt: dto.createdAt
                    )
                }
            }
        )
    }

    static let testValue = RoomRepository(
        fetchRooms: { [] }
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var roomRepository: RoomRepository {
        get { self[RoomRepositoryKey.self] }
        set { self[RoomRepositoryKey.self] = newValue }
    }
}
