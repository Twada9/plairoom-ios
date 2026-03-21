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
//   loadFailed → error   : リトライ失敗
//   error → loading : 再試行（ロード）を選択
//   error → idle    : キャンセルを選択
//   idle → requesting : ユーザーアクション
//   requesting → idle : 通信成功 / 失敗

import ComposableArchitecture
import Foundation

@Reducer
struct RoomListFeature {

    // MARK: - LoadState

    enum LoadState: Equatable {
        case loading
        case idle
        case loadFailed
        case error
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var loadState: LoadState = .loading
        var rooms: [Room] = []
        var errorMessage: String? = nil
        /// リトライ回数（loadFailed → error の判定に使用）
        var retryCount: Int = 0
        /// ルーム詳細へ遷移するルームID（feature/roomdetail で実装）
        var selectedRoomID: String? = nil
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case roomsResponse(Result<[Room], Error>)
        case retryTapped
        case cancelErrorTapped
        case roomTapped(Room)
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
                state.retryCount = 0
                return .none

            case .roomsResponse(.failure(let error)):
                let supabaseError = SupabaseError.from(error)
                if state.loadState == .loadFailed {
                    // 2回目の失敗 → error 状態
                    state.loadState = .error
                    state.errorMessage = supabaseError.userMessage
                } else {
                    // 1回目の失敗 → loadFailed 状態
                    state.loadState = .loadFailed
                    state.errorMessage = supabaseError.userMessage
                    state.retryCount += 1
                }
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
                // TODO: RoomDetailFeature への遷移（feature/roomdetail で実装）
                state.selectedRoomID = room.id
                return .none
            }
        }
    }
}
