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
    /// NOTE: `static let` (格納プロパティ) にすることでシングルトンを保証する。
    /// `static var` (計算プロパティ) にすると @Dependency を解決するたびに
    /// 新しいインスタンスが生成されセッション（JWT）が共有されないため 401 が発生する。
    static let liveValue: Supabase.SupabaseClient = {
        guard
            let projectRef = Bundle.main.infoDictionary?["SUPABASE_PROJECT_REF"] as? String,
            !projectRef.isEmpty,
            let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
            !anonKey.isEmpty,
            let url = URL(string: "https://\(projectRef).supabase.co")
        else {
            fatalError(
                "SUPABASE_PROJECT_REF または SUPABASE_ANON_KEY が Info.plist に設定されていません。"
            )
        }
        return Supabase.SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    // v3 での正式動作に今から合わせる
                    // https://github.com/supabase/supabase-swift/pull/822
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()

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
