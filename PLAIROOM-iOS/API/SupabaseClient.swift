//
//  SupabaseClient.swift
//  PLAIROOM-iOS
//

import Foundation
import Supabase
import Dependencies

// MARK: - SupabaseClient Dependency
//
// Supabase Swift SDK の SupabaseClient を swift-dependencies に登録する。
// カスタムラッパーは持たず、SDK のクライアントをそのまま DI に流す。
// 各 Feature では @Dependency(\.supabaseClient) で取得し、
//   supabaseClient.auth / supabaseClient.from / supabaseClient.functions
// を直接呼び出す。

extension DependencyValues {
    var supabaseClient: Supabase.SupabaseClient {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}

private enum SupabaseClientKey: DependencyKey {
    /// 本番環境: Info.plist から読み込んだ設定を使って SDK クライアントを生成
    static var liveValue: Supabase.SupabaseClient {
        let config = DependencyValues._current.supabaseConfig
        return Supabase.SupabaseClient(
            supabaseURL: config.projectURL,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    // v3 での正式動作に今から合わせる
                    // https://github.com/supabase/supabase-swift/pull/822
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    /// テスト環境: ダミー URL で初期化（実際の通信は発生しない）
    static let testValue = Supabase.SupabaseClient(
        supabaseURL: URL(string: "https://test-project-ref.supabase.co")!,
        supabaseKey: "test-anon-key",
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    /// プレビュー環境
    static let previewValue = Supabase.SupabaseClient(
        supabaseURL: URL(string: "https://preview-project-ref.supabase.co")!,
        supabaseKey: "preview-anon-key",
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
