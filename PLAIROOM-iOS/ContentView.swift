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
import Supabase
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

    // MARK: - CancelID

    nonisolated enum CancelID: Hashable {
        case generation(String)
    }

    // MARK: - GenerationTaskResult

    /// `runGeneration` 内の TaskGroup で各子タスクの完了事由を識別するための値
    nonisolated enum GenerationTaskResult: Sendable {
        case trackerFinished
        case edgeFunctionSucceeded
        case edgeFunctionFailed
    }

    // MARK: - Destination

    @Reducer
    enum Destination {
        case imageHistory(ImageHistoryFeature)
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

        @Shared(.inMemory("authState")) var authState: AuthState = .guest
        /// アプリのどこからでも認証画面を開けるようにする共有値
        /// trueにしたら表示される
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false

        /// アプリ全体で進行中の生成リクエスト
        @Shared(.inMemory("ongoingGenerations")) var ongoingGenerations: IdentifiedArrayOf<OngoingGeneration> = []

        /// MiniPlayer タップ時に表示する履歴シート
        @Presents var destination: Destination.State?
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

        // 生成管理
        case startGeneration(roomId: String, contentType: ContentType, prompt: String)
        case retryGeneration(requestId: String)
        case generationStatusChanged(requestId: String, status: OngoingGeneration.Status)
        case dismissGeneration(requestId: String)
        case miniPlayerTapped
        case destination(PresentationAction<Destination.Action>)
    }

    // MARK: - Dependencies

    @Dependency(\.authRepository) var authRepository
    @Dependency(\.generateRepository) var generateRepository
    @Dependency(\.generationTracker) var generationTracker
    @Dependency(\.supabaseClient) var supabaseClient
    @Dependency(\.uuid) var uuid

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
                return .send(.settings(.onAppear))

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

            case let .roomList(.delegate(.generationRequested(roomId, contentType, prompt))):
                return .send(.startGeneration(roomId: roomId, contentType: contentType, prompt: prompt))

            case .roomList:
                return .none

            case .settings:
                return .none

            case let .startGeneration(roomId, contentType, prompt):
                let requestId = uuid().uuidString.lowercased()
                let generation = OngoingGeneration(
                    id: requestId,
                    roomId: roomId,
                    contentType: contentType,
                    prompt: prompt,
                    status: .subscribing
                )
                state.$ongoingGenerations.withLock { $0[id: requestId] = generation }
                return runGeneration(requestId: requestId, roomId: roomId, contentType: contentType, prompt: prompt)

            case let .retryGeneration(requestId):
                guard let existing = state.ongoingGenerations[id: requestId] else {
                    return .none
                }
                state.$ongoingGenerations.withLock {
                    $0[id: requestId]?.status = .subscribing
                }
                // 古い Effect を確実に停止してから再度走らせる。
                // runGeneration 内の .cancellable(cancelInFlight:) だけでは
                // onTermination 経由の購読解除が次の購読開始前に完了する保証がないため、
                // ここで明示的に cancel → 新しい Effect の順に .concatenate する。
                return .concatenate(
                    .cancel(id: CancelID.generation(requestId)),
                    runGeneration(
                        requestId: requestId,
                        roomId: existing.roomId,
                        contentType: existing.contentType,
                        prompt: existing.prompt
                    )
                )

            case let .generationStatusChanged(requestId, status):
                state.$ongoingGenerations.withLock {
                    $0[id: requestId]?.status = status
                }
                return .none

            case let .dismissGeneration(requestId):
                state.$ongoingGenerations.withLock {
                    $0.remove(id: requestId)
                }
                return .cancel(id: CancelID.generation(requestId))

            case .miniPlayerTapped:
                let items = state.ongoingGenerations
                    .compactMap { $0.asImageContent }
                state.destination = .imageHistory(ImageHistoryFeature.State(items: items))
                return .none

            case .destination(.presented(.imageHistory(.delegate(.dismissed)))):
                state.destination = nil
                return .none

            case let .destination(.presented(.imageHistory(.delegate(.generationDismissed(contentId))))):
                // ImageHistory から contentId で通知されるので requestId に逆引き
                let requestId = state.ongoingGenerations.first(where: { gen in
                    if case let .completed(_, cid) = gen.status { return cid == contentId }
                    return false
                })?.id
                if let requestId {
                    return .send(.dismissGeneration(requestId: requestId))
                }
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$auth, action: \.auth) {
            AuthFeature()
        }
        .ifLet(\.$destination, action: \.destination)
    }

    // MARK: - Private

    /// Realtime 購読 + Edge Function 呼び出しを並行実行する Effect
    private func runGeneration(
        requestId: String,
        roomId: String,
        contentType: ContentType,
        prompt: String
    ) -> Effect<Action> {
        .run { send in
            // userId を取得
            let userId: String
            do {
                let session = try await supabaseClient.auth.session
                userId = session.user.id.uuidString.lowercased()
            } catch {
                await send(.generationStatusChanged(
                    requestId: requestId,
                    status: .failed(message: "認証セッションの取得に失敗しました")
                ))
                return
            }

            await withTaskGroup(of: GenerationTaskResult.self) { group in
                // 1. Realtime 購読タスク
                group.addTask {
                    for await update in generationTracker.track(userId, requestId) {
                        switch update {
                        case .subscribed:
                            await send(.generationStatusChanged(
                                requestId: requestId,
                                status: .generating
                            ))
                        case let .completed(fileUrl, contentId):
                            await send(.generationStatusChanged(
                                requestId: requestId,
                                status: .completed(fileUrl: fileUrl, contentId: contentId)
                            ))
                            return .trackerFinished
                        case let .failed(message):
                            await send(.generationStatusChanged(
                                requestId: requestId,
                                status: .failed(message: message)
                            ))
                            return .trackerFinished
                        }
                    }
                    return .trackerFinished
                }

                // 2. Edge Function 呼び出しタスク
                group.addTask {
                    do {
                        switch contentType {
                        case .image:
                            try await generateRepository.generateImage(roomId, prompt, userId, requestId)
                        case .music:
                            try await generateRepository.generateMusic(roomId, prompt, userId, requestId)
                        }
                        return .edgeFunctionSucceeded
                    } catch {
                        await send(.generationStatusChanged(
                            requestId: requestId,
                            status: .failed(message: SupabaseError.from(error).localizedDescription)
                        ))
                        return .edgeFunctionFailed
                    }
                }

                // どちらかの完了を待ち、残りの片方をキャンセル
                // - Tracker が完了/失敗を通知 → EF タスクは不要（既に走ってたら終了を待つ）
                // - EF が失敗 → Tracker は無限待ちするのでキャンセル必須
                while let result = await group.next() {
                    if result == .edgeFunctionFailed || result == .trackerFinished {
                        group.cancelAll()
                        break
                    }
                }
            }
        }
        .cancellable(id: CancelID.generation(requestId), cancelInFlight: true)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Namespace private var animationNamespace

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

    private var isMiniPlayerVisible: Bool {
        let gens = store.ongoingGenerations
        return !gens.isEmpty
    }

    private var pendingCount: Int {
        store.ongoingGenerations.count(where: { $0.status.isCompleted })
    }

    private var isAnyGenerating: Bool {
        store.ongoingGenerations.contains(where: { $0.status.isInFlight })
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
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.automatic)
        .tabViewBottomAccessory(isEnabled: isMiniPlayerVisible) {
            MiniPlayerView(
                pendingCount: pendingCount,
                isGenerating: isAnyGenerating
            ) {
                store.send(.miniPlayerTapped)
            }
            .matchedTransitionSource(id: "miniPlayer", in: animationNamespace)
        }
        .sheet(
            item: $store.scope(state: \.destination?.imageHistory, action: \.destination.imageHistory)
        ) { historyStore in
            ImageHistoryView(store: historyStore)
        }
    }
}

extension AppFeature.Destination.State: Equatable {}

// MARK: - Preview

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
