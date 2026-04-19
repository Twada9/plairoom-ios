//
//  OngoingGeneration.swift
//  PLAIROOM-iOS
//

import Foundation

/// アプリ全体で共有される「進行中の生成リクエスト」
struct OngoingGeneration: Equatable, Identifiable, Sendable {
    /// requestId (UUID lowercased)
    let id: String
    let roomId: String
    let contentType: ContentType
    let prompt: String
    var status: Status
}

extension OngoingGeneration {
    enum Status: Equatable, Sendable {
        case subscribing
        case generating
        case completed(fileUrl: String, contentId: String)
        case failed(message: String)

        var isInFlight: Bool {
            switch self {
            case .subscribing, .generating: return true
            case .completed, .failed: return false
            }
        }

        var isCompleted: Bool {
            if case .completed = self { return true }
            return false
        }

        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    /// 完了済みの生成のみ `ImageContent` として表現する。
    /// 未完了（subscribing/generating）や失敗は nil。
    var asImageContent: ImageContent? {
        guard case let .completed(fileUrl, contentId) = status else { return nil }
        return ImageContent(
            id: contentId,
            roomId: roomId,
            fileUrl: fileUrl,
            promptUsed: prompt,
            createdAt: Date(),
            status: .pending
        )
    }
}
