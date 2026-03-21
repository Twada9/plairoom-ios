//
//  RoomDTO.swift
//  PLAIROOM-iOS
//

import Foundation

/// Supabase rooms テーブルのレスポンス DTO
struct RoomDTO: Decodable, Sendable {
    let id: String
    let title: String
    let description: String
    let basePrompt: String
    let roomType: String
    let contentType: String
    let createdAt: String
}
