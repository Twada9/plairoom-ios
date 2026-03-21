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

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        /// AppFeature から渡される認証状態。View の分岐に使用する
        var isAuthenticated: Bool = false
        var userName: String = ""
        var userEmail: String = ""
        var isPremium: Bool = false
        var isRequesting: Bool = false
        var errorMessage: String? = nil
        var showLogoutConfirmation: Bool = false
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
        case delegate(Delegate)

        enum Delegate {
            /// ログインボタンタップ → AppFeature が Auth シートを表示
            case loginRequested
            /// ログアウト完了 → AppFeature が認証状態を未認証へ更新
            case loggedOut
        }
    }

    // MARK: - Dependencies

    @Dependency(\.authRepository) var authRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard state.isAuthenticated else { return .none }
                if let user = authRepository.currentUser() {
                    state.userEmail = user.email ?? ""
                    if case let .string(name) = user.userMetadata["name"] {
                        state.userName = name
                    }
                }
                return .none

            case .loginButtonTapped:
                return .send(.delegate(.loginRequested))

            case .logoutButtonTapped:
                state.showLogoutConfirmation = true
                return .none

            case .logoutCancelled:
                state.showLogoutConfirmation = false
                return .none

            case .logoutConfirmed:
                state.showLogoutConfirmation = false
                state.isRequesting = true
                state.errorMessage = nil
                return .run { send in
                    await send(.logoutResponse(
                        Result { try await authRepository.signOut() }
                    ))
                }

            case .logoutResponse(.success):
                state.isRequesting = false
                return .send(.delegate(.loggedOut))

            case .logoutResponse(.failure(let error)):
                state.isRequesting = false
                state.errorMessage = SupabaseError.from(error).localizedDescription
                return .none

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
    }
}
