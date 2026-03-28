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
    // AppFeatureで共有
    enum AuthState {
        case standard
        case premium
        case guest
        
        var isAuthenticated: Bool {
            return .guest != self
        }
    }
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        /// 起動時の認証チェック完了フラグ
        var isLaunching: Bool = true
        /// 認証状態（§02 Global Auth）
        var isAuthenticated: Bool = false
        /// ホーム画面（RoomList）
        var roomList: RoomListFeature.State = RoomListFeature.State()
        /// 設定画面（Settings）
        var settings: SettingsFeature.State = SettingsFeature.State()
        /// 認証モーダル（@Presents で管理。nil のとき非表示、値があるとき sheet 表示）
        @Presents var auth: AuthFeature.State?
        
        @Shared(.inMemory("authState")) var authState: AuthState = .standard
        /// アプリのどこからでも認証画面を開けるようにする共有値
        /// trueにしたら表示される
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false
    }
    
    // MARK: - Action
    
    enum Action {
        case onAppear
        case roomList(RoomListFeature.Action)
        case settings(SettingsFeature.Action)
        case auth(PresentationAction<AuthFeature.Action>)
        case authStateChanged(Bool)
        case showAuthView
        case onDismissAuthView
    }
    
    // MARK: - Dependencies
    
    @Dependency(\.authRepository) var authRepository
    
    // MARK: - Body
    
    var body: some Reducer<State, Action> {
        Scope(state: \.roomList, action: \.roomList) {
            RoomListFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
                
            case .onAppear:
                state.isLaunching = false
                return .run { send in
                    for await isAuth in await authRepository.authStateChanged() {
                        await send(.authStateChanged(isAuth))
                    }
                }
                
            case .auth(.presented(.delegate(.authSucceeded))):
                state.isAuthenticated = true
                state.$authState.withLock { $0 = state.isAuthenticated ? .standard : .guest }
                state.$showAuthViewTrigger.withLock { $0 = false }
                state.auth = nil
                return .none
                
            case .auth(.presented(.delegate(.cancelled))):
                // ゲストとしてホームへ継続（dismiss は @Presents が自動処理）
                return .none
                
            case let .authStateChanged(isAuth):
                // TODO: プレミアムかどうかの判定も必要
                state.$authState.withLock { $0 = isAuth ? .standard : .guest }
                
                if !state.authState.isAuthenticated {
                    // 未ログイン → ログインモーダル表示（§01: LoggedOut → ログインモーダル表示）
                    return .send(.showAuthView)
                }
                return .none
            case .showAuthView:
                state.auth = AuthFeature.State()
                return .none
            case .onDismissAuthView:
                state.$showAuthViewTrigger.withLock { $0 = false }
                return .none
            case .auth:
                return .none
                
            case .roomList:
                return .none
                
            case .settings:
                return .none
            }
        }
        .ifLet(\.$auth, action: \.auth) {
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
            item: $store.scope(state: \.auth, action: \.auth),
            onDismiss: {
                store.send(.onDismissAuthView)
            }, content: { authStore in
                AuthView(store: authStore)
            })
        .onChange(of: store.showAuthViewTrigger, { _, shouldShow in
            if shouldShow {
                store.send(.showAuthView)
            }
        })
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
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
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
