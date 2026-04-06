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
}

private struct GenerateResponseDTO: Decodable {
    let contentId: String
    let fileUrl: String
}

// MARK: - DependencyKey

private enum GenerateRepositoryKey: DependencyKey {
    static var liveValue: GenerateRepository {
        return GenerateRepository(
            generateImage: { roomId, prompt in
                @Dependency(\.supabaseClient) var client: SupabaseClient

                // セッションを明示的にリフレッシュし、アクセストークンを取得
                let session: Session
                do {
                    session = try await client.auth.session
                } catch {
                    // リフレッシュ失敗 → 認証エラー扱い
                    throw SupabaseError.unauthorized
                }

                // ── DEBUG: 送信ヘッダー確認（確認後削除） ──────────────
                let tokenPrefix = String(session.accessToken.prefix(40))

                // Secrets.xcconfig から読まれた値を確認
                let projectRef = Bundle.main.infoDictionary?["SUPABASE_PROJECT_REF"] as? String ?? "nil"
                let anonKeyRaw = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? "nil"

                // anon key の iss を確認（access token の iss と一致すべき）
                let anonParts = anonKeyRaw.split(separator: ".")
                if anonParts.count >= 2 {
                    var base64a = String(anonParts[1])
                    let rem = base64a.count % 4
                    if rem != 0 { base64a += String(repeating: "=", count: 4 - rem) }
                    if let d = Data(base64Encoded: base64a),
                       let p = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    }
                }

                // JWT ペイロードをデコードして発行元プロジェクトを確認
                let jwtParts = session.accessToken.split(separator: ".")
                if jwtParts.count >= 2 {
                    var base64 = String(jwtParts[1])
                    // Base64URL → Base64 パディング補正
                    let remainder = base64.count % 4
                    if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
                    if let payloadData = Data(base64Encoded: base64),
                       let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    }
                }
                // ────────────────────────────────────────────────────────

                let requestDTO = GenerateRequestDTO(roomId: roomId, prompt: prompt)
                let requestData = try JSONEncoder.snakeCaseEncoder.encode(requestDTO)

                let responseData: GenerateResponseDTO = try await client.functions
                    .invoke<GenerateResponseDTO>("generate-image", options: FunctionInvokeOptions(
                        body: requestData
                    ), decoder: JSONDecoder.snakeCaseDecoder)

//                let responseDTO = try await JSONDecoder.snakeCaseDecoder.decode(GenerateResponseDTO.self, from: responseData)
                return responseData.fileUrl
            },
            generateMusic: { roomId, prompt in
                @Dependency(\.supabaseClient) var client: SupabaseClient

                // セッションを明示的にリフレッシュし、アクセストークンを取得
                let session: Session
                do {
                    session = try await client.auth.session
                } catch {
                    // リフレッシュ失敗 → 認証エラー扱い
                    throw SupabaseError.unauthorized
                }

                let requestDTO = GenerateRequestDTO(roomId: roomId, prompt: prompt)
                let requestData = try JSONEncoder.snakeCaseEncoder.encode(requestDTO)

                // Authorization ヘッダーを明示的に付与
                let responseData: Data = try await client.functions
                    .invoke("generate-music", options: FunctionInvokeOptions(
                        body: requestData
                    ))

                let responseDTO = try await JSONDecoder.snakeCaseDecoder.decode(GenerateResponseDTO.self, from: responseData)
                return responseDTO.contentId
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
