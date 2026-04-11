//
//  ImageContent.swift
//  PLAIROOM-iOS
//

import Foundation

/// 画像生成コンテンツ（Mini Player 用）
struct ImageContent: Equatable, Identifiable {
    let id: String
    let roomId: String
    let fileUrl: String
    let promptUsed: String
    let createdAt: Date
    var status: Status

    enum Status: String, Equatable {
        case generating
        case pending
        case posted
        case discarded
    }
}
