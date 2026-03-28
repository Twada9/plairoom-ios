//
//  AuthFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §08) に準拠:
//
//   [*] → loginIdle
//   loginIdle  ⇄ signUpIdle   : タブ切り替え
//   loginIdle  → requesting   : ログインボタンタップ
//   signUpIdle → requesting   : 登録ボタンタップ
//   requesting → loginIdle   : 通信失敗 [AppError]（エラー表示付き）
//   requesting → [*]          : 通信成功 → delegate(.authSucceeded)
//   loginIdle  → [*]          : キャンセル → delegate(.cancelled)
//   signUpIdle → [*]          : キャンセル → delegate(.cancelled)

import ComposableArchitecture
import Foundation

@Reducer
struct AuthFeature {

    // MARK: - Tab

    enum Tab: Equatable {
        case login
        case signUp
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var tab: Tab = .login

        // ログインフォーム
        var loginEmail: String = ""
        var loginPassword: String = ""

        // 新規登録フォーム
        var signUpName: String = ""
        var signUpEmail: String = ""
        var signUpPassword: String = ""

        // 共通
        var isRequesting: Bool = false
        var errorMessage: String? = nil
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false

    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case tabChanged(Tab)
        case loginButtonTapped
        case signUpButtonTapped
        case cancelButtonTapped
        case authResponse(Result<Void, Error>)
        case delegate(Delegate)

        enum Delegate {
            case authSucceeded
            case cancelled
        }
    }

    // MARK: - Dependencies

    @Dependency(\.authRepository) var authRepository
    @Dependency(\.dismiss) var dismiss
    
    // MARK: - Body

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .binding:
                return .none

            case .tabChanged(let tab):
                state.tab = tab
                state.errorMessage = nil
                return .none

            case .loginButtonTapped:
                state.isRequesting = true
                state.errorMessage = nil
                let email = state.loginEmail
                let password = state.loginPassword
                return .run { [authRepository] send in
                    await send(.authResponse(
                        Result { try await authRepository.signIn(email, password) }
                    ))
                }

            case .signUpButtonTapped:
                state.isRequesting = true
                state.errorMessage = nil
                let email = state.signUpEmail
                let password = state.signUpPassword
                let name = state.signUpName
                return .run { [authRepository] send in
                    await send(.authResponse(
                        Result { try await authRepository.signUp(email, password, name) }
                    ))
                }

            case .cancelButtonTapped:
                return .run { _ in await dismiss() }

            case .authResponse(.success):
                state.isRequesting = false
                return .send(.delegate(.authSucceeded))

            case .authResponse(.failure(let error)):
                // 通信失敗 → loginIdle（状態遷移図準拠）
                state.isRequesting = false
                let supabaseError = SupabaseError.from(error)
                switch supabaseError {
                case .restError(_, let message, _):
                    state.errorMessage = message
                case .edgeFunctionError(_, let message):
                    state.errorMessage = message
                case .unauthorized:
                    state.errorMessage = "メールアドレスまたはパスワードが正しくありません"
                case .networkError:
                    state.errorMessage = "ネットワークエラーが発生しました"
                default:
                    state.errorMessage = "エラーが発生しました。もう一度お試しください。"
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
