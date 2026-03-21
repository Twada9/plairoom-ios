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
        guard let url = URL(string: "https://\(projectRef).supabase.co") else {
            fatalError(
                "Invalid Supabase project URL for projectRef: '\(projectRef)'. "
                + "Ensure SUPABASE_PROJECT_REF in Info.plist is a valid URL component."
            )
        }
        return url
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
    static let liveValue: SupabaseConfig = {
        guard
            let projectRef = Bundle.main.infoDictionary?["SUPABASE_PROJECT_REF"] as? String,
            !projectRef.isEmpty
        else {
            fatalError(
                "SUPABASE_PROJECT_REF is missing or empty in Info.plist. "
                + "Add SUPABASE_PROJECT_REF to your app's Info.plist or xcconfig with a valid Supabase project reference ID."
            )
        }
        guard
            let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
            !anonKey.isEmpty
        else {
            fatalError(
                "SUPABASE_ANON_KEY is missing or empty in Info.plist. "
                + "Add SUPABASE_ANON_KEY to your app's Info.plist or xcconfig with a valid Supabase anonymous key."
            )
        }
        return SupabaseConfig(projectRef: projectRef, anonKey: anonKey)
    }()

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
