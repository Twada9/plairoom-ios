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
import Supabase

// MARK: - Request / Response

private struct GenerateRequest: Encodable {
    let roomId: String
    let prompt: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case prompt
    }
}

private struct GenerateResponse: Decodable {
    let contentId: String

    enum CodingKeys: String, CodingKey {
        case contentId = "content_id"
    }
}

// MARK: - GenerateFeature

@Reducer
struct GenerateFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        let room: Room
        var promptText: String = ""
        var isRequesting: Bool = false
        var errorMessage: String? = nil
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitButtonTapped
        case generateResponse(Result<String, Error>)
        case delegate(Delegate)

        enum Delegate {
            /// 生成リクエスト受付済み → 結果画面へ（content_id を渡す）
            case generationStarted(contentId: String, room: Room)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.supabaseClient) var supabaseClient

    // MARK: - Body

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .binding:
                return .none

            case .submitButtonTapped:
                guard !state.promptText.trimmingCharacters(in: .whitespaces).isEmpty else {
                    state.errorMessage = "プロンプトを入力してください"
                    return .none
                }
                state.isRequesting = true
                state.errorMessage = nil
                let functionName = state.room.contentType == "image"
                    ? "generate-image"
                    : "generate-music"
                let request = GenerateRequest(
                    roomId: state.room.id,
                    prompt: state.promptText
                )
                return .run { [supabaseClient] send in
                    await send(.generateResponse(
                        Result {
                            let response: GenerateResponse = try await supabaseClient.functions
                                .invoke(functionName, options: FunctionInvokeOptions(body: request))
                            return response.contentId
                        }
                    ))
                }

            case .generateResponse(.success(let contentId)):
                state.isRequesting = false
                let room = state.room
                return .send(.delegate(.generationStarted(contentId: contentId, room: room)))

            case .generateResponse(.failure(let error)):
                state.isRequesting = false
                let supabaseError = SupabaseError.from(error)
                switch supabaseError {
                case .edgeFunctionError(let type, let message):
                    switch type {
                    case .usageLimitExceeded:
                        state.errorMessage = "今月の生成回数上限に達しました"
                    case .unauthorized:
                        state.errorMessage = "ログインが必要です"
                    default:
                        state.errorMessage = message
                    }
                case .networkError:
                    state.errorMessage = "ネットワークエラーが発生しました"
                default:
                    state.errorMessage = "生成に失敗しました。もう一度お試しください。"
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
