//
//  GenerateRepository.swift
//  PLAIROOM-iOS
//

import Dependencies
import Foundation
import Supabase

// MARK: - GenerateRepository

/// 生成リポジトリ
///
/// Edge Functions (generate-image / generate-music) を呼び出す。
/// Realtime 購読は `GenerationTracker` に分離されているため、このリポジトリは
/// 単純に Edge Function へリクエストを投げるだけ。
struct GenerateRepository: Sendable {
    /// 画像生成リクエスト。成功時は Edge Function が 200 を返すことのみを保証。
    /// 生成結果（file_url）は Realtime broadcast で別経路で通知される。
    var generateImage: @Sendable (
        _ roomId: String,
        _ prompt: String,
        _ userId: String,
        _ requestId: String
    ) async throws -> Void

    /// 音楽生成リクエスト
    var generateMusic: @Sendable (
        _ roomId: String,
        _ prompt: String,
        _ userId: String,
        _ requestId: String
    ) async throws -> Void
}

// MARK: - Request / Response DTOs

private struct GenerateRequestDTO: Encodable {
    let roomId: String
    let prompt: String
    let userId: String
    let requestId: String
}

private struct GenerateResponseDTO: Decodable {
    let success: Bool
}

// MARK: - DependencyKey

private enum GenerateRepositoryKey: DependencyKey {
    static var liveValue: GenerateRepository {
        GenerateRepository(
            generateImage: { roomId, prompt, userId, requestId in
                @Dependency(\.supabaseClient) var client: SupabaseClient

                let requestDTO = GenerateRequestDTO(
                    roomId: roomId,
                    prompt: prompt,
                    userId: userId,
                    requestId: requestId
                )
                let requestData = try JSONEncoder.snakeCaseEncoder.encode(requestDTO)
                let _: GenerateResponseDTO = try await client.functions.invoke(
                    "generate-image",
                    options: FunctionInvokeOptions(body: requestData),
                    decoder: JSONDecoder.snakeCaseDecoder
                )
            },
            generateMusic: { _, _, _, _ in
                // TODO: generate-music Edge Function 実装後に対応
            }
        )
    }

    static let testValue = GenerateRepository(
        generateImage: unimplemented("\(GenerateRepository.self).generateImage"),
        generateMusic: unimplemented("\(GenerateRepository.self).generateMusic")
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var generateRepository: GenerateRepository {
        get { self[GenerateRepositoryKey.self] }
        set { self[GenerateRepositoryKey.self] = newValue }
    }
}
