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
struct GenerateRepository: Sendable {
    /// 画像生成リクエスト
    var generateImage: @Sendable (_ roomId: String, _ prompt: String) async throws -> String

    /// 音楽生成リクエスト
    var generateMusic: @Sendable (_ roomId: String, _ prompt: String) async throws -> String
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
        var channel: RealtimeChannelV2?
        return GenerateRepository(
            generateImage: { roomId, prompt in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                @Dependency(\.uuid) var uuid: UUIDGenerator

                // セッションを明示的にリフレッシュし、アクセストークンを取得
                let session: Session
                do {
                    session = try await client.auth.session
                } catch {
                    // リフレッシュ失敗 → 認証エラー扱い
                    throw SupabaseError.unauthorized
                }

                // ユーザーIDとリクエストIDを取得
                guard let userId = session.user.id.uuidString.lowercased() as String? else {
                    throw SupabaseError.unauthorized
                }
                let requestId = UUID().uuidString
                // リクエストDTO作成
                let requestDTO = GenerateRequestDTO(
                    roomId: roomId,
                    prompt: prompt,
                    userId: userId,
                    requestId: requestId
                )
                // 1. チャンネルの準備
                let channelName = "user:\(userId):\(requestId)"
                channel = client.channel(channelName) {
                    $0.isPrivate = true
                }
                guard let channel else { throw SupabaseError.unknown(message: "channelがnilです。") }
                // 2. 先にBroadcastストリームを取得しておく（これ自体は同期的に可能）
                let broadcastStream = channel.broadcastStream(event: "content_updated")

                // 3. 確実に「購読完了」を待機する
                print("⏳ [GenerateRepository] Subscribing...")
                try! await channel.subscribeWithError()
                print("📡 [GenerateRepository] Subscribed!")

                // 4. Broadcast受信用のタスクを開始
                let broadcastTask = Task<String, Error> {
                    for await message in broadcastStream {
                        print("📥 [GenerateRepository] Received broadcast: \(message)")
                        if case let .string(fileUrl) = message["file_url"] {
                            await channel.unsubscribe()
                            return fileUrl
                        }
                    }
                    throw SupabaseError.edgeFunctionError(type: .serverError, message: "Stream closed without data")
                }

                // 5. 購読が「完了している状態」でAPIを叩く
                print("🚀 [GenerateRepository] Calling API...")
                do {
                    let requestData = try JSONEncoder.snakeCaseEncoder.encode(requestDTO)
                    let _: GenerateResponseDTO = try await client.functions.invoke(
                        "generate-image",
                        options: FunctionInvokeOptions(body: requestData),
                        decoder: JSONDecoder.snakeCaseDecoder
                    )
                    print("✅ [GenerateRepository] API call accepted, waiting for broadcast...")
                } catch {
                    broadcastTask.cancel() // APIが失敗したらタスクもキャンセル
                    throw error
                }

                // 6. 最後にBroadcastの結果を待つ
                return try await broadcastTask.value
            },
            generateMusic: { roomId, prompt in
                return ""
//                @Dependency(\.supabaseClient) var client: SupabaseClient
//
//                // セッションを明示的にリフレッシュし、アクセストークンを取得
//                let session: Session
//                do {
//                    session = try await client.auth.session
//                } catch {
//                    // リフレッシュ失敗 → 認証エラー扱い
//                    throw SupabaseError.unauthorized
//                }
//
//                let requestDTO = GenerateRequestDTO(roomId: roomId, prompt: prompt)
//                let requestData = try JSONEncoder.snakeCaseEncoder.encode(requestDTO)
//
//                // Authorization ヘッダーを明示的に付与
//                let responseData: Data = try await client.functions
//                    .invoke("generate-music", options: FunctionInvokeOptions(
//                        body: requestData
//                    ))
//
//                let responseDTO = try await JSONDecoder.snakeCaseDecoder.decode(GenerateResponseDTO.self, from: responseData)
//                return responseDTO.contentId
            }
        )
    }

    static let testValue = GenerateRepository(
        generateImage: unimplemented(),
        generateMusic: unimplemented()
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var generateRepository: GenerateRepository {
        get { self[GenerateRepositoryKey.self] }
        set { self[GenerateRepositoryKey.self] = newValue }
    }
}
