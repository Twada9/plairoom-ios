//
//  ContentItem.swift
//  PLAIROOM-iOS
//

import Foundation

/// コンテンツのステータス
enum ContentStatus: String, Equatable, Decodable, Sendable {
    case generating
    case pending
    case completed
    case failed
}

/// 画像・音楽共通のコンテンツエンティティ
///
/// `image_contents` / `music_contents` テーブルを共通モデルで表現する。
/// 音楽の場合のみ `duration` が非 nil になる。
struct ContentItem: Equatable, Identifiable, Sendable {
    let id: String
    let userId: String
    let roomId: String
    let fileUrl: String?
    let promptUsed: String?
    let status: ContentStatus
    let createdAt: String
    /// いいね数（JOIN で取得）
    let likeCount: Int
    /// 投稿者名（profiles JOIN）
    let authorName: String?
    let authorAvatarUrl: String?
    /// 音楽コンテンツのみ（秒数）
    let duration: Int?
}
