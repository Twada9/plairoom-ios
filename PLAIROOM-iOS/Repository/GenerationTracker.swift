//
//  GenerationTracker.swift
//  PLAIROOM-iOS
//
// アプリ全体で共有される「生成リクエストのRealtime購読管理」。
// AppFeature が各リクエストに対して `start` を呼び、購読結果を
// AsyncStream として受け取る。
// RoomDetail や Generate の画面が破棄されても購読は継続する。

import Dependencies
import Foundation
import Supabase

// MARK: - GenerationUpdate

/// Realtime 購読から AppFeature へ通知される状態更新
enum GenerationUpdate: Sendable, Equatable {
    /// 購読完了 → Edge Function 呼び出し中
    case subscribed
    /// Broadcast 受信完了（file_url / content_id 取得）
    case completed(fileUrl: String, contentId: String)
    /// 何らかの失敗
    case failed(message: String)
}

// MARK: - GenerationTracker

/// 生成リクエストの Realtime 購読を管理する依存
struct GenerationTracker: Sendable {
    /// 指定された userId / requestId のチャンネルを購読し、状態更新を AsyncStream で返す。
    ///
    /// - Parameters:
    ///   - userId: auth.user.id.uuidString.lowercased()
    ///   - requestId: クライアント側で発行した requestId（UUID lowercased）
    /// - Returns: 購読状態の更新ストリーム。1件目は `.subscribed`、その後 `.completed` または `.failed` で完了する。
    var track: @Sendable (_ userId: String, _ requestId: String) -> AsyncStream<GenerationUpdate>
}

// MARK: - DependencyKey

private enum GenerationTrackerKey: DependencyKey {
    static var liveValue: GenerationTracker {
        GenerationTracker(
            track: { userId, requestId in
                AsyncStream<GenerationUpdate> { continuation in
                    let task = Task {
                        @Dependency(\.supabaseClient) var client: SupabaseClient

                        let channelName = "user:\(userId):\(requestId)"
                        let channel = client.channel(channelName) {
                            $0.isPrivate = true
                        }
                        let broadcastStream = channel.broadcastStream(event: "content_updated")

                        do {
                            try await channel.subscribeWithError()
                            print("📡 [GenerationTracker] Subscribed: \(channelName)")
                            continuation.yield(.subscribed)
                        } catch {
                            print("❌ [GenerationTracker] Subscribe failed: \(error)")
                            continuation.yield(.failed(message: "購読に失敗しました: \(error.localizedDescription)"))
                            continuation.finish()
                            return
                        }

                        for await message in broadcastStream {
                            print("📥 [GenerationTracker] Received: \(message)")
                            // broadcast message の実データは `payload` キーの中にネストされている
                            let inner: [String: AnyJSON]
                            if case let .object(obj) = message["payload"] ?? .null {
                                inner = obj
                            } else {
                                inner = message
                            }
                            let fileUrl = inner["file_url"]?.stringValue
                            let contentId = inner["id"]?.stringValue
                            print("📥 [GenerationTracker] fileUrl=\(fileUrl ?? "nil"), contentId=\(contentId ?? "nil")")

                            if let fileUrl, let contentId {
                                continuation.yield(.completed(fileUrl: fileUrl, contentId: contentId))
                                break
                            }
                        }

                        await channel.unsubscribe()
                        continuation.finish()
                    }

                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }
        )
    }

    static let testValue = GenerationTracker(
        track: unimplemented("\(GenerationTracker.self).track")
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var generationTracker: GenerationTracker {
        get { self[GenerationTrackerKey.self] }
        set { self[GenerationTrackerKey.self] = newValue }
    }
}
