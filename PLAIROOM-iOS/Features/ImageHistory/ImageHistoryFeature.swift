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
        var items: [ImageContent]
        var selectedTab: Tab = .image
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
                // 成功したら items から削除
                state.items.removeAll { $0.id == id }
                return .none

            case .postFailure:
                // TODO: エラーハンドリング
                return .none

            case .discardSuccess(let id):
                // 成功したら items から削除
                state.items.removeAll { $0.id == id }
                return .none

            case .discardFailure:
                // TODO: エラーハンドリング
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
