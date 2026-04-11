//
//  GenerateFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §06) に準拠:
//
//   [*] → idle
//   idle → requesting : 送信ボタンタップ（Edge Function 呼び出し）
//   requesting → idle : 通信失敗 [AppError]
//   requesting → [*]  : 通信成功 → delegate(.generationStarted)

import ComposableArchitecture
import Foundation

// MARK: - GenerateFeature

@Reducer
struct GenerateFeature {

    // MARK: - ContentStatus

    enum ContentStatus: Equatable {
        case pending
        case generating
        case completed
        case failed
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        let room: Room
        var promptText: String = ""
        var contentStatus: ContentStatus = .pending
        var failureReason: String? = nil
        var showLoginAlert: Bool = false
        var imageUrl: String? = nil
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitButtonTapped
        case generateResponse(Result<String, Error>)
        case loginButtonTapped
        case dismissLoginAlert
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        /// 生成リクエスト開始 → RoomDetailFeature に通知
        case generationStarted(roomId: String)
    }

    // MARK: - Dependencies

    @Dependency(\.generateRepository) var generateRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .binding:
                return .none

            case .submitButtonTapped:
                guard !state.promptText.trimmingCharacters(in: .whitespaces).isEmpty else {
                    state.contentStatus = .failed
                    state.failureReason = "プロンプトを入力してください"
                    return .none
                }

                state.contentStatus = .generating
                state.failureReason = nil
                let roomId = state.room.id
                let prompt = state.promptText
                let contentType = state.room.contentType

                // Fire-and-forget: 生成リクエストを投げたら即座に delegate に通知
                return .run { [generateRepository] send in
                    // 生成開始を即座に通知
                    await send(.delegate(.generationStarted(roomId: roomId)))

                    // バックグラウンドで生成処理（結果は Realtime で受け取る）
                    _ = await Result {
                        switch contentType {
                        case .image:
                            return try await generateRepository.generateImage(roomId, prompt)
                        case .music:
                            return try await generateRepository.generateMusic(roomId, prompt)
                        }
                    }
                }

            case .generateResponse:
                // fire-and-forget なので response は無視
                return .none

            case .loginButtonTapped:
                state.showLoginAlert = false
                state.$showAuthViewTrigger.withLock { $0 = true }
                return .none

            case .dismissLoginAlert:
                state.showLoginAlert = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
