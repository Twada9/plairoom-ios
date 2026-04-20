//
//  ImageHistoryFeature.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import Foundation

@Reducer
struct ImageHistoryFeature {

    // MARK: - Tab

    enum Tab: String, CaseIterable, Equatable {
        case image
        // case music // 後回し
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        /// アプリ全体で共有される進行中の生成一覧。
        /// items はこれから派生して算出するため、
        /// シート表示中に新規完了が入れば自動で追加される。
        @Shared(.inMemory("ongoingGenerations")) var ongoingGenerations: IdentifiedArrayOf<OngoingGeneration> = []
        var selectedTab: Tab = .image

        /// 画面に表示するアイテム。完了済みの OngoingGeneration のみを
        /// ImageContent に変換して返す。
        var items: [ImageContent] {
            ongoingGenerations.compactMap { $0.asImageContent }
        }
    }

    // MARK: - Action

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case postTapped(id: String)
        case discardTapped(id: String)
        case postSuccess(id: String)
        case postFailure(id: String, String)
        case discardSuccess(id: String)
        case discardFailure(id: String, String)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case dismissed
        /// シート上で破棄/投稿された生成リクエストを親（AppFeature）へ通知
        case generationDismissed(requestId: String)
    }

    // MARK: - Dependencies

    @Dependency(\.contentRepository) var contentRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .binding:
                return .none

            case .onAppear:
                return .none

            case .postTapped(let id):
                // TODO: status を "posted" に更新
                return .run { send in
                    do {
                        // contentRepository で status 更新
                        // try await contentRepository.updateContentStatus(id, .posted)
                        await send(.postSuccess(id: id))
                    } catch {
                        await send(.postFailure(id: id, error.localizedDescription))
                    }
                }

            case .discardTapped(let id):
                // TODO: status を "discarded" に更新
                return .run { send in
                    do {
                        // contentRepository で status 更新
                        // try await contentRepository.updateContentStatus(id, .discarded)
                        await send(.discardSuccess(id: id))
                    } catch {
                        await send(.discardFailure(id: id, error.localizedDescription))
                    }
                }

            case .postSuccess(let id):
                // items は派生プロパティなので、親に通知して
                // ongoingGenerations 側から該当エントリを削除してもらう。
                return .send(.delegate(.generationDismissed(requestId: id)))

            case .postFailure:
                // TODO: エラーハンドリング
                return .none

            case .discardSuccess(let id):
                return .send(.delegate(.generationDismissed(requestId: id)))

            case .discardFailure:
                // TODO: エラーハンドリング
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
