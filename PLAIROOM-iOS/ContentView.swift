//
//  ContentView.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import ComposableArchitecture
import SwiftUI

// MARK: - AppFeature (仮: AppFeature 実装後に置き換え)

@Reducer
struct AppFeature {

    @ObservableState
    struct State {
        var isAuthenticated: Bool = false
        var auth: AuthFeature.State? = AuthFeature.State()
    }

    enum Action {
        case auth(AuthFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .auth(.delegate(.authSucceeded)):
                state.isAuthenticated = true
                state.auth = nil
                return .none
            case .auth(.delegate(.cancelled)):
                // ゲストとしてホームへ（TODO: ホーム画面実装後に対応）
                return .none
            case .auth:
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
        if store.isAuthenticated {
            // TODO: ホーム画面（RoomList）へ遷移
            Text("ホーム（準備中）")
        } else if let authStore = store.scope(state: \.auth, action: \.auth) {
            AuthView(store: authStore)
        }
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
