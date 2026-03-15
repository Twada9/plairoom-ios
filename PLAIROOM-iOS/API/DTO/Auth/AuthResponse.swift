//
//  AuthResponse.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import Foundation

/// Supabase Auth API のレスポンス
struct AuthResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let user: AuthUser
}
