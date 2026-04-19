//
//  GenerateFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §06) に準拠:
//
//   [*] → idle
//   idle → requesting : 送信ボタンタップ
//   requesting → [*]  : delegate(.generationRequested) → AppFeature が処理

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
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitButtonTapped
        case loginButtonTapped
        case dismissLoginAlert
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        /// 生成リクエストを AppFeature に委譲
        case generationRequested(roomId: String, contentType: ContentType, prompt: String)
    }

    // MARK: - Body

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .binding:
                return .none

            case .submitButtonTapped:
                let trimmed = state.promptText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    state.contentStatus = .failed
                    state.failureReason = "プロンプトを入力してください"
                    return .none
                }

                state.contentStatus = .generating
                state.failureReason = nil
                return .send(.delegate(.generationRequested(
                    roomId: state.room.id,
                    contentType: state.room.contentType,
                    prompt: trimmed
                )))

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
