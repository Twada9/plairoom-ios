//
//  URLRequest+Supabase.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import Foundation

extension URLRequest {
    /// Supabase API用の共通ヘッダーを設定
    ///
    /// - Parameters:
    ///   - config: Supabase設定
    ///   - token: JWT トークン（認証が必要な場合）
    ///   - contentType: Content-Type ヘッダー（デフォルト: application/json）
    nonisolated mutating func setSupabaseHeaders(
        config: SupabaseConfig,
        token: String? = nil,
        contentType: String? = "application/json"
    ) {
        // 必須: apikey ヘッダー
        setValue(config.anonKey, forHTTPHeaderField: "apikey")

        // オプション: Content-Type
        if let contentType {
            setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        // オプション: Authorization (認証が必要な場合)
        if let token {
            setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}
