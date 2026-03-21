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
}

// MARK: - DependencyKey

private enum AuthRepositoryKey: DependencyKey {
    static var liveValue: AuthRepository {
        let client = DependencyValues._current.supabaseClient
        return AuthRepository(
            signIn: { email, password in
                try await client.auth.signIn(email: email, password: password)
            },
            signUp: { email, password, name in
                try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: ["name": AnyJSON.string(name)]
                )
            },
            signOut: {
                try await client.auth.signOut()
            },
            currentUser: {
                client.auth.currentUser
            }
        )
    }

    static let testValue = AuthRepository(
        signIn: { _, _ in },
        signUp: { _, _, _ in },
        signOut: {},
        currentUser: { nil }
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var authRepository: AuthRepository {
        get { self[AuthRepositoryKey.self] }
        set { self[AuthRepositoryKey.self] = newValue }
    }
}
