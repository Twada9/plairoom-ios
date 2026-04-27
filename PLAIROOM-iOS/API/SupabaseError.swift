//
//  SupabaseError.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "SupabaseError")

/// Supabase API のエラー型
enum SupabaseError: Error, Sendable {
    /// REST API / Auth API のエラー
    case restError(code: String, message: String, details: String?)

    /// Edge Function のカスタムエラー
    case edgeFunctionError(type: EdgeFunctionErrorType, message: String)

    /// ネットワークエラー
    case networkError(message: String)

    /// デコードエラー
    case decodingError(message: String)

    /// 不正なレスポンス
    case invalidResponse(statusCode: Int)

    /// 認証エラー（トークン未設定）
    case unauthorized

    /// その他のエラー
    case unknown(message: String)
}

/// Edge Function のエラー種別
enum EdgeFunctionErrorType: String, Sendable {
    /// 月間生成回数上限超過
    case usageLimitExceeded

    /// 認証エラー
    case unauthorized

    /// サーバーエラー
    case serverError

    /// ネットワークエラー
    case networkError

    /// 不明なエラー
    case unknown
}

// MARK: - Error Response DTOs

/// Supabase REST / Auth API エラーレスポンス
struct SupabaseRESTErrorResponse: Decodable, Sendable {
    let code: String
    let message: String
    let details: String?
    let hint: String?
}

/// Edge Function エラーレスポンス（カスタム形式: {"error": {"type": "...", "message": "..."}}）
struct EdgeFunctionErrorResponse: Decodable, Sendable {
    let error: EdgeFunctionErrorDetail
}

struct EdgeFunctionErrorDetail: Decodable, Sendable {
    let type: String
    let message: String
}

/// Supabase リレー / Gateway エラーレスポンス（{"code": 401, "message": "Invalid JWT"} 形式）
struct SupabaseRelayErrorResponse: Decodable, Sendable {
    let code: Int
    let message: String
}

// MARK: - SDK Error Mapping

extension SupabaseError {
    /// Supabase Swift SDK が throw するエラーを SupabaseError にマッピングする
    ///
    /// - `FunctionsError.httpError` → Edge Function のレスポンスをパースして `edgeFunctionError` または `invalidResponse`
    /// - `PostgrestError`           → `restError`
    /// - `AuthError`                → `unauthorized` または `restError`
    /// - その他                     → `unknown`
    static func from(_ error: Error) -> SupabaseError {
        // すでに SupabaseError ならそのまま返す
        if let e = error as? SupabaseError { return e }

        // Edge Function エラー
        if let e = error as? FunctionsError {
            switch e {
            case .httpError(let code, let data):
                let rawBody = String(data: data, encoding: .utf8) ?? "(decode failed)"
                logger.error("HTTP \(code, privacy: .public): \(rawBody, privacy: .public)")

                // {"error": {"type": "...", "message": "..."}} 形式（Edge Function カスタムエラー）
                if let edgeError = try? JSONDecoder().decode(EdgeFunctionErrorResponse.self, from: data) {
                    let errorType = EdgeFunctionErrorType(rawValue: edgeError.error.type) ?? .unknown
                    return .edgeFunctionError(type: errorType, message: edgeError.error.message)
                }

                // {"code": 401, "message": "..."} 形式（Supabase リレーエラー）
                if let relayError = try? JSONDecoder().decode(SupabaseRelayErrorResponse.self, from: data) {
                    // リレーエラーは unauthorized として扱う（401 = JWT invalid）
                    if relayError.code == 401 {
                        return .edgeFunctionError(type: .unauthorized, message: relayError.message)
                    }
                    return .invalidResponse(statusCode: relayError.code)
                }

                return .invalidResponse(statusCode: code)
            case .relayError:
                return .networkError(message: e.localizedDescription)
            @unknown default:
                return .unknown(message: e.localizedDescription)
            }
        }

        // PostgREST エラー
        if let e = error as? PostgrestError {
            return .restError(
                code: e.code ?? "",
                message: e.message,
                details: e.detail
            )
        }

        // Auth エラー
        if error is AuthError {
            return .unauthorized
        }

        return .unknown(message: error.localizedDescription)
    }
}

// MARK: - LocalizedError

extension SupabaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .restError(let code, let message, _):
            return "Supabase Error [\(code)]: \(message)"
        case .edgeFunctionError(let type, let message):
            return "Edge Function Error [\(type.rawValue)]: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .decodingError(let message):
            return "Decoding Error: \(message)"
        case .invalidResponse(let statusCode):
            return "Invalid Response: HTTP \(statusCode)"
        case .unauthorized:
            return "Unauthorized: JWT token is missing or invalid"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
}
