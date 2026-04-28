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
        var errorMessage: String? = nil

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
        case errorDismissed
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case dismissed
        /// シート上で破棄/投稿された生成リクエストを親（AppFeature）へ通知
        case generationDismissed(contentId: String)
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
                guard let generation = state.ongoingGenerations.first(where: {
                    guard case let .completed(_, contentId) = $0.status else { return false }
                    return contentId == id
                }) else { return .none }
                let postContentType = generation.contentType
                return .run { send in
                    do {
                        try await contentRepository.patchStatus(id, postContentType, .completed)
                        await send(.postSuccess(id: id))
                    } catch {
                        await send(.postFailure(id: id, error.localizedDescription))
                    }
                }

            case .discardTapped(let id):
                guard let generation = state.ongoingGenerations.first(where: {
                    guard case let .completed(_, contentId) = $0.status else { return false }
                    return contentId == id
                }) else { return .none }
                let discardContentType = generation.contentType
                return .run { send in
                    do {
                        try await contentRepository.patchStatus(id, discardContentType, .failed)
                        await send(.discardSuccess(id: id))
                    } catch {
                        await send(.discardFailure(id: id, error.localizedDescription))
                    }
                }

            case .postSuccess(let id):
                // items は派生プロパティなので、親に通知して
                // ongoingGenerations 側から該当エントリを削除してもらう。
                return .send(.delegate(.generationDismissed(contentId: id)))

            case .postFailure(_, let message):
                state.errorMessage = message
                return .none

            case .discardSuccess(let id):
                return .send(.delegate(.generationDismissed(contentId: id)))

            case .discardFailure(_, let message):
                state.errorMessage = message
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
