//
//  AuthUser.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import Foundation

/// Supabase Auth のユーザー情報
struct AuthUser: Decodable, Sendable {
    let id: String
    let email: String?
}
