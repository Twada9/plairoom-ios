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
        let client = DependencyValues._current.supabaseClient
        return RoomRepository(
            fetchRooms: {
                let dtos: [RoomDTO] = try await client
                    .from("rooms")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                return dtos.map { dto in
                    Room(
                        id: dto.id,
                        title: dto.title,
                        description: dto.description,
                        basePrompt: dto.basePrompt,
                        roomType: dto.roomType,
                        contentType: dto.contentType,
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
