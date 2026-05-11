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
        /// 使用状況（nil = 未取得）
        var usageStatus: UsageStatus? = nil
        /// リワード広告の視聴処理中フラグ
        var isGrantingReward: Bool = false
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case usageStatusResponse(Result<UsageStatus, Error>)
        case submitButtonTapped
        case loginButtonTapped
        case dismissLoginAlert
        /// リワード広告視聴完了（AdMob コールバックから呼ぶ）
        case rewardEarned
        case grantRewardResponse(Result<UsageStatus, Error>)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        /// 生成リクエストを AppFeature に委譲
        case generationRequested(roomId: String, contentType: ContentType, prompt: String)
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

            case .onAppear:
                return .run { send in
                    await send(.usageStatusResponse(
                        Result { try await generateRepository.checkUsageLimit() }
                    ))
                }

            case let .usageStatusResponse(.success(status)):
                state.usageStatus = status
                return .none

            case .usageStatusResponse(.failure):
                // 取得失敗時は UI を隠すだけ（生成は試みられる）
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
                state.$showAuthViewTrigger.withLock { $0 = true }
                return .none

            case .dismissLoginAlert:
                return .none

            case .rewardEarned:
                state.isGrantingReward = true
                return .run { send in
                    await send(.grantRewardResponse(
                        Result { try await generateRepository.grantReward() }
                    ))
                }

            case let .grantRewardResponse(.success(status)):
                state.isGrantingReward = false
                state.usageStatus = status
                return .none

            case .grantRewardResponse(.failure):
                state.isGrantingReward = false
                state.failureReason = "リワードの付与に失敗しました。もう一度お試しください"
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
