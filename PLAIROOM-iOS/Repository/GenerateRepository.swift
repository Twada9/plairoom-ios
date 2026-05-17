//
//  GenerateRepository.swift
//  PLAIROOM-iOS
//

import Dependencies
import Foundation
import Supabase

// MARK: - UsageStatus

struct UsageStatus: Equatable, Sendable, Decodable {
    let used: Int
    let limit: Int
    let remaining: Int
    let isPremium: Bool
    /// 今日あと何回リワード広告を視聴できるか（0〜3）
    let rewardRemaining: Int
    init(used: Int, limit: Int, remaining: Int, isPremium: Bool, rewardRemaining: Int) {
        self.used = used
        self.limit = limit
        self.remaining = remaining
        self.isPremium = isPremium
        self.rewardRemaining = rewardRemaining
    }
}

// MARK: - GenerateRepository

/// 生成リポジトリ
///
/// Edge Functions (generate-image / generate-music / check-usage-limit / grant-reward) を呼び出す。
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

    /// 今日の使用状況を取得
    var checkUsageLimit: @Sendable () async throws -> UsageStatus

    /// リワード広告視聴完了後にボーナスを付与
    var grantReward: @Sendable () async throws -> UsageStatus
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

private struct GrantRewardResponseDTO: Decodable {
    let remaining: Int
    let rewardRemaining: Int
    let effectiveLimit: Int
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
            },
            checkUsageLimit: {
                @Dependency(\.supabaseClient) var client: SupabaseClient
                return try await client.functions.invoke(
                    "check-usage-limit",
                    options: FunctionInvokeOptions(method: .get),
                    decoder: JSONDecoder.snakeCaseDecoder
                )
            },
            grantReward: {
                @Dependency(\.supabaseClient) var client: SupabaseClient
                let dto: GrantRewardResponseDTO = try await client.functions.invoke(
                    "grant-reward",
                    decoder: JSONDecoder.snakeCaseDecoder
                )
                return UsageStatus(
                    used: 0,
                    limit: dto.effectiveLimit,
                    remaining: dto.remaining,
                    // TODO: アカウントのプレミアムができたら直す
                    isPremium: false,
                    rewardRemaining: dto.rewardRemaining
                )
            }
        )
    }

    static let testValue = GenerateRepository(
        generateImage: unimplemented("\(GenerateRepository.self).generateImage"),
        generateMusic: unimplemented("\(GenerateRepository.self).generateMusic"),
        checkUsageLimit: unimplemented("\(GenerateRepository.self).checkUsageLimit"),
        grantReward: unimplemented("\(GenerateRepository.self).grantReward")
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var generateRepository: GenerateRepository {
        get { self[GenerateRepositoryKey.self] }
        set { self[GenerateRepositoryKey.self] = newValue }
    }
}
