//
//  SupabaseClient.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import Foundation
import Dependencies

/// Supabase API クライアント
///
/// URLSession と Swift Concurrency を使用した Supabase 専用クライアント
/// Swift 6 Strict Concurrency に準拠するため actor として実装
actor SupabaseClient {
    // MARK: - Properties

    private let config: SupabaseConfig
    private let session: URLSession
    private var jwtToken: String?

    // MARK: - Initialization

    init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - JWT Token Management

    /// JWT トークンを設定
    func setToken(_ token: String) {
        self.jwtToken = token
    }

    /// JWT トークンを取得
    func getToken() -> String? {
        return jwtToken
    }

    /// JWT トークンをクリア
    func clearToken() {
        self.jwtToken = nil
    }

    // MARK: - REST API

    /// REST API GET リクエスト
    ///
    /// - Parameters:
    ///   - endpoint: エンドポイントパス（例: "/rooms"）
    ///   - queryItems: クエリパラメータ
    ///   - requiresAuth: 認証が必要かどうか
    /// - Returns: デコードされたレスポンス
    func get<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = false
    ) async throws -> T {
        let url = await config.restBaseURL.appendingPathComponent(endpoint)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setSupabaseHeaders(
            config: config,
            token: requiresAuth ? jwtToken : nil,
            contentType: nil
        )

        if requiresAuth && jwtToken == nil {
            throw SupabaseError.unauthorized
        }

        return try await performRequest(request)
    }

    /// REST API POST リクエスト
    ///
    /// - Parameters:
    ///   - endpoint: エンドポイントパス
    ///   - body: リクエストボディ（Encodable）
    ///   - prefer: Prefer ヘッダーの値（例: "return=representation"）
    ///   - requiresAuth: 認証が必要かどうか
    /// - Returns: デコードされたレスポンス
    func post<T: Decodable, Body: Encodable>(
        endpoint: String,
        body: Body,
        prefer: String? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = await config.restBaseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder.snakeCaseEncoder.encode(body)
        request.setSupabaseHeaders(
            config: config,
            token: requiresAuth ? jwtToken : nil
        )
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        if requiresAuth && jwtToken == nil {
            throw SupabaseError.unauthorized
        }

        return try await performRequest(request)
    }

    /// REST API PATCH リクエスト
    ///
    /// - Parameters:
    ///   - endpoint: エンドポイントパス
    ///   - queryItems: クエリパラメータ（条件指定用）
    ///   - body: リクエストボディ（Encodable）
    ///   - prefer: Prefer ヘッダーの値
    ///   - requiresAuth: 認証が必要かどうか
    /// - Returns: デコードされたレスポンス
    func patch<T: Decodable, Body: Encodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        body: Body,
        prefer: String? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = await config.restBaseURL.appendingPathComponent(endpoint)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.httpBody = try JSONEncoder.snakeCaseEncoder.encode(body)
        request.setSupabaseHeaders(
            config: config,
            token: requiresAuth ? jwtToken : nil
        )
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        if requiresAuth && jwtToken == nil {
            throw SupabaseError.unauthorized
        }

        return try await performRequest(request)
    }

    /// REST API DELETE リクエスト
    ///
    /// - Parameters:
    ///   - endpoint: エンドポイントパス
    ///   - queryItems: クエリパラメータ（条件指定用）
    ///   - requiresAuth: 認証が必要かどうか
    func delete(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) async throws {
        let url = await config.restBaseURL.appendingPathComponent(endpoint)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setSupabaseHeaders(
            config: config,
            token: requiresAuth ? jwtToken : nil,
            contentType: nil
        )

        if requiresAuth && jwtToken == nil {
            throw SupabaseError.unauthorized
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse(statusCode: 0)
        }

        // DELETE は 204 No Content を期待
        guard (200...299).contains(httpResponse.statusCode) else {
            try handleErrorResponse(data: Data(), response: httpResponse)
        }
    }

    // MARK: - Auth API

    /// サインアップ
    ///
    /// - Parameters:
    ///   - email: メールアドレス
    ///   - password: パスワード
    ///   - metadata: 追加データ（例: name）
    /// - Returns: 認証レスポンス
    func signUp(
        email: String,
        password: String,
        metadata: [String: String] = [:]
    ) async throws -> AuthResponse {
        let url = await config.authBaseURL.appendingPathComponent("/signup")
        print(url)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setSupabaseHeaders(config: config)

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "options": ["data": metadata]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await performRequest(request)
    }

    /// ログイン
    ///
    /// - Parameters:
    ///   - email: メールアドレス
    ///   - password: パスワード
    /// - Returns: 認証レスポンス
    func signIn(email: String, password: String) async throws -> AuthResponse {
        let url = await config.authBaseURL.appendingPathComponent("/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setSupabaseHeaders(config: config)

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder.snakeCaseEncoder.encode(body)

        return try await performRequest(request)
    }

    /// ログアウト
    func signOut() async throws {
        guard let token = jwtToken else {
            throw SupabaseError.unauthorized
        }

        let url = await config.authBaseURL.appendingPathComponent("/logout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setSupabaseHeaders(config: config, token: token, contentType: nil)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse(statusCode: 0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            try handleErrorResponse(data: Data(), response: httpResponse)
        }

        clearToken()
    }

    /// トークンリフレッシュ
    ///
    /// - Parameter refreshToken: リフレッシュトークン
    /// - Returns: 認証レスポンス
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        let url = await config.authBaseURL.appendingPathComponent("/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setSupabaseHeaders(config: config)

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder.snakeCaseEncoder.encode(body)

        return try await performRequest(request)
    }

    // MARK: - Edge Functions

    /// Edge Function を呼び出す
    ///
    /// - Parameters:
    ///   - functionName: 関数名（例: "generate-image"）
    ///   - body: リクエストボディ（Encodable）
    /// - Returns: デコードされたレスポンス
    func callFunction<T: Decodable, Body: Encodable>(
        _ functionName: String,
        body: Body
    ) async throws -> T {
        guard let token = jwtToken else {
            throw SupabaseError.unauthorized
        }

        let url = await config.functionsBaseURL.appendingPathComponent(functionName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setSupabaseHeaders(config: config, token: token)
        request.httpBody = try JSONEncoder.snakeCaseEncoder.encode(body)

        return try await performRequest(request)
    }

    /// Edge Function を呼び出す（GET）
    ///
    /// - Parameter functionName: 関数名（例: "check-usage-limit"）
    /// - Returns: デコードされたレスポンス
    func callFunctionGet<T: Decodable>(_ functionName: String) async throws -> T {
        guard let token = jwtToken else {
            throw SupabaseError.unauthorized
        }

        let url = await config.functionsBaseURL.appendingPathComponent(functionName)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setSupabaseHeaders(config: config, token: token, contentType: nil)

        return try await performRequest(request)
    }

    // MARK: - Private Methods

    /// リクエストを実行してレスポンスをデコード
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse(statusCode: 0)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                try handleErrorResponse(data: data, response: httpResponse)
            }

            do {
                return try JSONDecoder.snakeCaseDecoder.decode(T.self, from: data)
            } catch {
                throw SupabaseError.decodingError(error)
            }
        } catch let error as SupabaseError {
            throw error
        } catch {
            throw SupabaseError.networkError(error)
        }
    }

    /// エラーレスポンスを処理
    private func handleErrorResponse(data: Data, response: HTTPURLResponse) throws -> Never {
        // Edge Function エラーのパース試行
        if let edgeError = try? JSONDecoder.snakeCaseDecoder.decode(EdgeFunctionErrorResponse.self, from: data) {
            let errorType = EdgeFunctionErrorType(rawValue: edgeError.error.type) ?? .unknown
            throw SupabaseError.edgeFunctionError(type: errorType, message: edgeError.error.message)
        }

        // Supabase REST/Auth エラーのパース試行
        if let restError = try? JSONDecoder.snakeCaseDecoder.decode(SupabaseRESTErrorResponse.self, from: data) {
            throw SupabaseError.restError(
                code: restError.code,
                message: restError.message,
                details: restError.details
            )
        }

        // その他のエラー
        throw SupabaseError.invalidResponse(statusCode: response.statusCode)
    }
}

// MARK: - SupabaseClient Dependency

extension DependencyValues {
    /// Supabase APIクライアントの依存性
    var supabaseClient: SupabaseClient {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}

private enum SupabaseClientKey: DependencyKey {
    @MainActor
    static let liveValue = SupabaseClient(
        config: DependencyValues._current.supabaseConfig
    )

    static let testValue = { unimplemented("") }

    static let previewValue = { unimplemented("") }
}
