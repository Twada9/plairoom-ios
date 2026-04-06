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

        enum Delegate {
            /// 生成リクエスト受付済み → 結果画面へ（content_id を渡す）
            case generationStarted(contentId: String, room: Room)
        }
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

                return .run { [generateRepository] send in
                    await send(.generateResponse(
                        Result {
                            switch contentType {
                            case .image:
                                return try await generateRepository.generateImage(roomId, prompt)
                            case .music:
                                return try await generateRepository.generateMusic(roomId, prompt)
                            }
                        }
                    ))
                }

            case .generateResponse(.success(let fileUrl)):
                state.contentStatus = .completed
                state.imageUrl = fileUrl
                let room = state.room
                // Note: contentId を返していないが、delegate では使わないため問題なし
                return .send(.delegate(.generationStarted(contentId: fileUrl, room: room)))

            case .generateResponse(.failure(let error)):
                state.contentStatus = .failed
                let supabaseError = SupabaseError.from(error)
                switch supabaseError {
                case .edgeFunctionError(let type, let message):
                    switch type {
                    case .usageLimitExceeded:
                        state.failureReason = "今月の生成回数上限に達しました"
                    case .unauthorized:
                        // TODO: ログイン時でも実行されると困るので念の為に制御を入れる
                        state.showLoginAlert = true
                    default:
                        state.failureReason = message
                    }
                case .networkError:
                    state.failureReason = "ネットワークエラーが発生しました"
                default:
                    state.failureReason = "生成に失敗しました。もう一度お試しください。"
                }
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
