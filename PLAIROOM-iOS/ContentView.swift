//
//  ContentView.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §01, §02) に準拠:
//
//   §01 アプリ起動:
//     Launching → AuthChecking → LoggedIn  → ホーム画面へ
//                              → LoggedOut → ログインモーダル表示
//
//   §02 Global Auth:
//     Unauthenticated ⇄ Authenticated

import ComposableArchitecture
import SwiftUI

// MARK: - AppFeature

@Reducer
struct AppFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        /// 起動時の認証チェック完了フラグ
        var isLaunching: Bool = true
        /// 認証状態（§02 Global Auth）
        var isAuthenticated: Bool = false
        /// ホーム画面（RoomList）
        var roomList: RoomListFeature.State = RoomListFeature.State()
        /// 認証モーダル（未ログイン時またはゲストが認証が必要な操作をした時に表示）
        var auth: AuthFeature.State? = nil
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case roomList(RoomListFeature.Action)
        case auth(AuthFeature.Action)
        case authModalDismissed
    }

    // MARK: - Dependencies

    @Dependency(\.authRepository) var authRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        Scope(state: \.roomList, action: \.roomList) {
            RoomListFeature()
        }
        Reduce { state, action in
            switch action {

            case .onAppear:
                // 起動時に認証状態を確認（§01）
                let isAuthenticated = authRepository.currentUser() != nil
                state.isAuthenticated = isAuthenticated
                state.isLaunching = false
                state.roomList.isAuthenticated = isAuthenticated
                if !isAuthenticated {
                    // 未ログイン → ログインモーダル表示（§01: LoggedOut → ログインモーダル表示）
                    state.auth = AuthFeature.State()
                }
                return .none

            case .auth(.delegate(.authSucceeded)):
                state.isAuthenticated = true
                state.auth = nil
                state.roomList.isAuthenticated = true
                return .none

            case .auth(.delegate(.cancelled)):
                // ゲストとしてホームへ継続
                state.auth = nil
                return .none

            case .authModalDismissed:
                state.auth = nil
                return .none

            case .auth:
                return .none

            case .roomList:
                return .none
            }
        }
        .ifLet(\.auth, action: \.auth) {
            AuthFeature()
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isLaunching {
                splashView
            } else {
                mainView
            }
        }
        .onAppear { store.send(.onAppear) }
        .sheet(
            isPresented: Binding(
                get: { store.auth != nil },
                set: { if !$0 { store.send(.authModalDismissed) } }
            )
        ) {
            if let authStore = store.scope(state: \.auth, action: \.auth) {
                AuthView(store: authStore)
            }
        }
    }

    private var splashView: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainView: some View {
        TabView {
            RoomListView(store: store.scope(state: \.roomList, action: \.roomList))
                .tabItem {
                    Label("ルーム", systemImage: "house.fill")
                }
            // TODO: SettingsView（feature/settings で実装）
            Text("設定（準備中）")
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
