//
//  RoomListFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §04) に準拠:
//
//   [*] → loading
//   loading → idle       : ロード完了
//   loading → loadFailed : ロード失敗
//   loadFailed → loading : リトライ

import ComposableArchitecture
import Foundation

@Reducer
struct RoomListFeature {

    // MARK: - LoadState

    enum LoadState: Equatable {
        case loading
        case idle
        case loadFailed
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var loadState: LoadState = .loading
        var rooms: [Room] = []
        var errorMessage: String? = nil
        /// ログイン済みかどうか（AuthModal 表示判定に使用）
        var isAuthenticated: Bool = false
        
        var auth: AuthFeature.State? = nil
        /// ルーム詳細への遷移
        @Presents var roomDetail: RoomDetailFeature.State?
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case roomsResponse(Result<[Room], Error>)
        case retryTapped
        case cancelErrorTapped
        case roomTapped(Room)
        // 認証モーダル
        case authModalDismissed
        case auth(AuthFeature.Action)
        // ログアウト通知受け取り（AppFeatureから）
        case setAuthenticated(Bool)
        // ルーム詳細
        case roomDetail(PresentationAction<RoomDetailFeature.Action>)
    }

    // MARK: - Dependencies

    @Dependency(\.roomRepository) var roomRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard state.loadState != .idle else { return .none }
                state.loadState = .loading
                state.errorMessage = nil
                return .run { send in
                    await send(.roomsResponse(
                        Result { try await roomRepository.fetchRooms() }
                    ))
                }

            case .roomsResponse(.success(let rooms)):
                state.loadState = .idle
                state.rooms = rooms
                return .none

            case .roomsResponse(.failure(let error)):
//                let supabaseError = SupabaseError.from(error)
                // TODO: 後のブランチでエラー文言関連をまとめる等する。
                state.loadState = .loadFailed
                state.errorMessage = "エラーが発生しました。もう一度お試しください。"
                return .none

            case .retryTapped:
                state.loadState = .loading
                state.errorMessage = nil
                return .run { send in
                    await send(.roomsResponse(
                        Result { try await roomRepository.fetchRooms() }
                    ))
                }

            case .cancelErrorTapped:
                state.loadState = .idle
                state.errorMessage = nil
                return .none

            case .roomTapped(let room):
                state.roomDetail = RoomDetailFeature.State(room: room)
                return .none

            case .setAuthenticated(let value):
                state.isAuthenticated = value
                return .none

            case .authModalDismissed:
                state.auth = nil
                return .none

            case .auth(.delegate(.authSucceeded)):
                state.isAuthenticated = true
                state.auth = nil
                return .none

            case .auth(.delegate(.cancelled)):
                state.auth = nil
                return .none

            case .auth:
                return .none

            case .roomDetail:
                return .none
            }
        }
        .ifLet(\.auth, action: \.auth) {
            AuthFeature()
        }
        .ifLet(\.$roomDetail, action: \.roomDetail) {
            RoomDetailFeature()
        }
    }
}
