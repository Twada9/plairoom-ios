//
//  ResultFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §07) に準拠:
//
//   [*] → idle
//   idle → requesting     : 投稿ボタンタップ（status → completed）
//   requesting → idle     : 通信失敗 [AppError]
//   requesting → [*]      : 通信成功 → delegate(.posted)
//   idle → [*]            : キャンセル（戻る）→ delegate(.cancelled)
//   idle → [*]            : やり直す → delegate(.retried)（status → failed）

import ComposableArchitecture
import Foundation

// MARK: - ResultFeature

@Reducer
struct ResultFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        let contentId: String
        let room: Room
        var content: ContentItem? = nil
        /// 進行中の操作。nil = idle / .post = 投稿中 / .retry = やり直し中
        var requestingAction: Action.PostAction? = nil
        var errorMessage: String? = nil

        var isRequesting: Bool { requestingAction != nil }
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case postButtonTapped
        case retryButtonTapped
        case cancelButtonTapped
        case patchResponse(Result<Void, Error>, action: PostAction)
        case delegate(Delegate)

        enum Delegate {
            /// 投稿完了 → ルーム詳細へ戻る
            case posted
            /// キャンセル → ルーム詳細へ戻る
            case cancelled
            /// やり直し → 生成画面へ戻る
            case retried(room: Room)
        }

        enum PostAction: Equatable { case post, retry }
    }

    // MARK: - Dependencies

    @Dependency(\.contentRepository) var contentRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .none

            case .postButtonTapped:
                guard state.requestingAction == nil else { return .none }
                state.requestingAction = .post
                state.errorMessage = nil
                let contentId = state.contentId
                let contentType = state.room.contentType
                return .run { send in
                    await send(.patchResponse(
                        Result { try await contentRepository.patchStatus(contentId, contentType, .completed) },
                        action: .post
                    ))
                }

            case .retryButtonTapped:
                guard state.requestingAction == nil else { return .none }
                state.requestingAction = .retry
                state.errorMessage = nil
                let contentId = state.contentId
                let contentType = state.room.contentType
                return .run { send in
                    await send(.patchResponse(
                        Result { try await contentRepository.patchStatus(contentId, contentType, .failed) },
                        action: .retry
                    ))
                }

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case .patchResponse(.success, let postAction):
                state.requestingAction = nil
                switch postAction {
                case .post:
                    return .send(.delegate(.posted))
                case .retry:
                    let room = state.room
                    return .send(.delegate(.retried(room: room)))
                }

            case .patchResponse(.failure(let error), _):
                state.requestingAction = nil
                state.errorMessage = SupabaseError.from(error).localizedDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
