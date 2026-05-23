//
//  SettingsFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §09) に準拠:
//
//   [*] → idle（isAuthenticated により表示分岐）
//   idle(guest)  → [*] : ログインボタン → delegate(.loginRequested)
//   idle(logged) → [*] : ログアウト → AppFeature が Unauthenticated へ遷移

import ComposableArchitecture
import Foundation
import Supabase

// MARK: - SettingsFeature

@Reducer
struct SettingsFeature {

    enum LoadState: Equatable {
        case loading
        case idle
        case loadFailed
    }

    // MARK: - 退会確認シートの子 State

    enum DeleteAccountLoadState: Equatable {
        case idle
        case loading
        case failed(String)
    }

    @ObservableState
    struct DeleteAccountSheetState: Equatable, Identifiable {
        let id = UUID()
        var password: String = ""
        var loadState: DeleteAccountLoadState = .idle
    }

    @CasePathable
    enum DeleteAccountSheetAction: BindableAction {
        case binding(BindingAction<DeleteAccountSheetState>)
        case cancelTapped
        case confirmTapped
        case response(Result<Void, Error>)

//        static func == (lhs: DeleteAccountSheetAction, rhs: DeleteAccountSheetAction) -> Bool {
//            false
//        }
    }
    
    // MARK: - State

    @ObservableState
    struct State: Equatable {
        /// AppFeature から渡される認証状態。View の分岐に使用する
        var userName: String = ""
        var userEmail: String = ""
        var loadState: LoadState = .idle
        var errorMessage: String? = nil
        var showLogoutConfirmation: Bool = false
        @Presents var deleteAccountSheet: DeleteAccountSheetState?
        @Shared(.inMemory("authState")) var authState: AppFeature.AuthState = .guest
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        /// ゲスト状態でログイン/登録ボタンをタップ
        case loginButtonTapped
        case logoutButtonTapped
        case logoutConfirmed
        case logoutCancelled
        case logoutResponse(Result<Void, Error>)
        case deleteAccountButtonTapped
        case deleteAccountSheet(PresentationAction<DeleteAccountSheetAction>)
    }

    // MARK: - Dependencies

    @Dependency(\.authRepository) var authRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                
            case .onAppear:
                guard state.authState.isAuthenticated else { return .none }
                if let user = authRepository.currentUser() {
                    state.userEmail = user.email ?? ""
                    if case let .string(name) = user.userMetadata["name"] {
                        state.userName = name
                    }
                }
                return .none
                
            case .loginButtonTapped:
                // authを表示する共有値をtrueにする
                state.$showAuthViewTrigger.withLock { $0 = true }
                return .none
                
            case .logoutButtonTapped:
                state.showLogoutConfirmation = true
                return .none
                
            case .logoutCancelled:
                state.showLogoutConfirmation = false
                return .none
                
            case .logoutConfirmed:
                state.showLogoutConfirmation = false
                state.loadState = .loading
                state.errorMessage = nil
                return .run { send in
                    await send(.logoutResponse(
                        Result { try await authRepository.signOut() }
                    ))
                }
                
            case .logoutResponse(.success):
                state.loadState = .idle
                return .none

            case .logoutResponse(.failure(let error)):
                state.loadState = .loadFailed
                // TODO: エラー周りは後ほどリファクタする。
//                state.errorMessage = SupabaseError.from(error).localizedDescription
                state.errorMessage = "エラーが発生しました。"
                return .none

            case .deleteAccountButtonTapped:
                state.deleteAccountSheet = DeleteAccountSheetState()
                return .none

            case .deleteAccountSheet(.presented(.cancelTapped)):
                state.deleteAccountSheet = nil
                return .none

            case .deleteAccountSheet(.presented(.confirmTapped)):
                guard let password = state.deleteAccountSheet?.password, !password.isEmpty else {
                    state.deleteAccountSheet?.loadState = .failed("パスワードを入力してください。")
                    return .none
                }
                state.deleteAccountSheet?.password = ""
                state.deleteAccountSheet?.loadState = .loading
                return .run { send in
                    await send(.deleteAccountSheet(.presented(.response(
                        Result { try await authRepository.deleteAccount(password) }
                    ))))
                }

            case .deleteAccountSheet(.presented(.response(.success))):
                // signOut() により authStateChanged ストリームが発火 → AppFeature がゲスト状態へ遷移
                state.deleteAccountSheet = nil
                return .none

            case let .deleteAccountSheet(.presented(.response(.failure(error)))):
                let supabaseError = SupabaseError.from(error)
                let message: String
                if case .edgeFunctionError(let type, _) = supabaseError, type == .invalidCredentials {
                    message = "パスワードが正しくありません。"
                } else {
                    message = "エラーが発生しました。時間をおいて再試行してください。"
                }
                state.deleteAccountSheet?.loadState = .failed(message)
                return .none

            case .deleteAccountSheet(.presented(.binding)):
                return .none

            case .deleteAccountSheet(.dismiss):
                return .none

            case .binding:
                return .none
            }
        }
        .ifLet(\.$deleteAccountSheet, action: \.deleteAccountSheet) {
            BindingReducer()
        }
    }
}
