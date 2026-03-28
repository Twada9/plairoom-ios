//
//  AuthRepository.swift
//  PLAIROOM-iOS
//

import Dependencies
import Foundation
import Supabase

// MARK: - AuthRepository

/// 認証リポジトリ
///
/// TCA の struct-based dependency パターンで定義。
/// 各クロージャが Supabase SDK の Auth 操作をラップする。
struct AuthRepository: Sendable {
    /// ログイン
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> Void
    /// 新規登録
    var signUp: @Sendable (_ email: String, _ password: String, _ name: String) async throws -> Void
    /// ログアウト
    var signOut: @Sendable () async throws -> Void
    /// 現在ログイン中のユーザー（未ログインなら nil）
    var currentUser: @Sendable () -> User?
    /// ログイン状態のストリーム
    var authStateChanged: @Sendable () -> AsyncStream<Bool>
}

// MARK: - DependencyKey

private enum AuthRepositoryKey: DependencyKey {
    static var liveValue: AuthRepository {
        return AuthRepository(
            signIn: { email, password in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                try await client.auth.signIn(email: email, password: password)
            },
            signUp: { email, password, name in
                @Dependency(\.supabaseClient) var client: SupabaseClient
                try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: ["name": AnyJSON.string(name)]
                )
            },
            signOut: {
                @Dependency(\.supabaseClient) var client: SupabaseClient
                try await client.auth.signOut()
            },
            currentUser: {
                @Dependency(\.supabaseClient) var client: SupabaseClient
                return client.auth.currentUser
            },
            authStateChanged: {
                @Dependency(\.supabaseClient) var client: SupabaseClient
                // TODO: まだ最低限のログイン状態のみを取得する。今後はプレミアムかどうかの問合せを統合する。
                // TODO: TaskがAsyncStreamが終了しても解放されていないかもしれない
                return AsyncStream { continuation in
                    Task {
                        for await (event, session) in client.auth.authStateChanges {
                            continuation.yield(session != nil)
                        }
                        return continuation.finish()
                    }
                }
            }
        )
    }

    static let testValue = AuthRepository(
        signIn: { _, _ in },
        signUp: { _, _, _ in },
        signOut: {},
        currentUser: { nil },
        authStateChanged: unimplemented()
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var authRepository: AuthRepository {
        get { self[AuthRepositoryKey.self] }
        set { self[AuthRepositoryKey.self] = newValue }
    }
}
