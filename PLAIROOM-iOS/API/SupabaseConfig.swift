//
//  SupabaseConfig.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import Foundation
import Dependencies

/// Supabaseプロジェクトの設定値
struct SupabaseConfig: Sendable {
    /// Supabaseプロジェクト参照ID
    let projectRef: String

    /// Supabase Anonymous Key (公開API用)
    let anonKey: String

    /// Supabase SDK に渡すプロジェクト URL
    var projectURL: URL {
        URL(string: "https://\(projectRef).supabase.co")!
    }
}

// MARK: - SupabaseConfig Dependency

extension DependencyValues {
    /// Supabase設定の依存性
    var supabaseConfig: SupabaseConfig {
        get { self[SupabaseConfigKey.self] }
        set { self[SupabaseConfigKey.self] = newValue }
    }
}

private enum SupabaseConfigKey: DependencyKey {
    /// 本番環境用の設定値（Info.plistから読み込む）
    @MainActor
    static let liveValue = SupabaseConfig(
        projectRef: Bundle.main.infoDictionary?["SUPABASE_PROJECT_REF"] as? String ?? "",
        anonKey: Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    )

    /// テスト環境用の設定値
    static let testValue = SupabaseConfig(
        projectRef: "test-project-ref",
        anonKey: "test-anon-key"
    )

    /// プレビュー環境用の設定値
    static let previewValue = SupabaseConfig(
        projectRef: "preview-project-ref",
        anonKey: "preview-anon-key"
    )
}
