//
//  RoomDetailFeature.swift
//  PLAIROOM-iOS
//
// 状態遷移図 (state-transition.md §05) に準拠:
//
//   [*] → loading
//   loading → idle       : ロード完了
//   loading → loadFailed : ロード失敗
//   loadFailed → loading : リトライ
//   loadFailed → error   : リトライ失敗
//   error → loading : 再試行を選択
//   error → idle    : キャンセルを選択
//   idle → requesting : いいね / いいね解除
//   requesting → idle : 通信成功 / 失敗 [AppError]
//   idle → [*] : 生成ボタンタップ → delegate(.generateTapped)
//             （画面遷移は AppFeature が担当）

import ComposableArchitecture
import Foundation

@Reducer
struct RoomDetailFeature {

    // MARK: - CancelID

    nonisolated enum CancelID {
        case loadContents
        case likedStatus
    }

    // MARK: - LoadState

    enum LoadState: Equatable {
        case loading
        case idle
        case loadFailed
    }

    // MARK: - Destination

    @Reducer
    enum Destination {
        case generate(GenerateFeature)
        case imageHistory(ImageHistoryFeature)
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        let room: Room
        var loadState: LoadState = .loading
        var contents: [ContentItem] = []
        var likedContentIds: Set<String> = []
        var likingContentIds: Set<String> = []
        var errorMessage: String? = nil

        @Shared(.inMemory("authState")) var authState: AppFeature.AuthState = .guest
        @Shared(.inMemory("showAuthViewTrigger")) var showAuthViewTrigger: Bool = false

        /// 画面遷移先
        @Presents var destination: Destination.State?
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case contentsResponse(Result<[ContentItem], Error>)
        case likedStatusResponse(Result<Set<String>, Error>)
        case retryTapped
        case cancelErrorTapped
        case likeButtonTapped(ContentItem)
        case likeResponse(Result<Void, Error>, contentId: String, isLiking: Bool)
        case generateButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        /// Generate 画面から上がってきた生成リクエストを親（AppFeature）へ中継
        case generationRequested(roomId: String, contentType: ContentType, prompt: String)
    }

    // MARK: - Dependencies

    @Dependency(\.contentRepository) var contentRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard state.loadState != .idle else {
                    return .none
                }
                return loadContents(state: &state)

            case .contentsResponse(.success(let contents)):
                state.contents = contents
                state.loadState = .idle
                // いいね状態を並行取得
                let ids = contents.map(\.id)
                let contentType = state.room.contentType
                return .run { [ids, contentType] send in
                    await send(.likedStatusResponse(
                        Result {
                            let liked = try await withThrowingTaskGroup(of: (String, Bool).self) { group in
                                for id in ids {
                                    group.addTask {
                                        let isLiked = try await contentRepository.isLiked(id, contentType)
                                        return (id, isLiked)
                                    }
                                }
                                var likedIds = Set<String>()
                                for try await (id, isLiked) in group {
                                    if isLiked {
                                        likedIds.insert(id)
                                    }
                                }

                                return likedIds
                            }
                            return liked
                        }
                    ))
                }
                .cancellable(id: CancelID.likedStatus, cancelInFlight: true)

            case .contentsResponse(.failure(let error)):
                state.loadState = .loadFailed
                state.errorMessage = error.localizedDescription
                return .none

            case .likedStatusResponse(.success(let ids)):
                state.likedContentIds = ids
                return .none

            case .likedStatusResponse(.failure):
                return .none

            case .retryTapped:
                return loadContents(state: &state)

            case .cancelErrorTapped:
                state.loadState = .idle
                state.errorMessage = nil
                return .none

            case .likeButtonTapped(let content):
                guard state.authState.isAuthenticated else {
                    state.$showAuthViewTrigger.withLock { $0 = true }
                    return .none
                }
                // 通信中の場合は早期return
                guard !state.likingContentIds.contains(content.id) else {
                    return .none
                }

                state.likingContentIds.insert(content.id)
                let isLiking = !state.likedContentIds.contains(content.id)
                // like UI 更新
                if isLiking {
                    state.likedContentIds.insert(content.id)
                    if let idx = state.contents.firstIndex(where: { $0.id == content.id }) {
                        let c = state.contents[idx]
                        state.contents[idx] = ContentItem(
                            id: c.id, userId: c.userId, roomId: c.roomId,
                            fileUrl: c.fileUrl, promptUsed: c.promptUsed,
                            status: c.status, createdAt: c.createdAt,
                            likeCount: c.likeCount + 1,
                            authorName: c.authorName, authorAvatarUrl: c.authorAvatarUrl,
                            duration: c.duration
                        )
                    }
                } else {
                    state.likedContentIds.remove(content.id)
                    if let idx = state.contents.firstIndex(where: { $0.id == content.id }) {
                        let c = state.contents[idx]
                        state.contents[idx] = ContentItem(
                            id: c.id, userId: c.userId, roomId: c.roomId,
                            fileUrl: c.fileUrl, promptUsed: c.promptUsed,
                            status: c.status, createdAt: c.createdAt,
                            likeCount: max(0, c.likeCount - 1),
                            authorName: c.authorName, authorAvatarUrl: c.authorAvatarUrl,
                            duration: c.duration
                        )
                    }
                }
                let contentId = content.id
                let contentType = state.room.contentType
                return .run { send in
                    await send(.likeResponse(
                        Result {
                            if isLiking {
                                try await contentRepository.likeContent(contentId, contentType)
                            } else {
                                try await contentRepository.unlikeContent(contentId, contentType)
                            }
                        },
                        contentId: contentId,
                        isLiking: isLiking
                    ))
                }

            case .likeResponse(.success, let contentId, _):
                state.likingContentIds.remove(contentId)
                return .none

            case .likeResponse(.failure(let error), let contentId, let isLiking):
                state.likingContentIds.remove(contentId)
                // like UI を巻き戻す
                if isLiking {
                    state.likedContentIds.remove(contentId)
                    if let idx = state.contents.firstIndex(where: { $0.id == contentId }) {
                        let c = state.contents[idx]
                        state.contents[idx] = ContentItem(
                            id: c.id, userId: c.userId, roomId: c.roomId,
                            fileUrl: c.fileUrl, promptUsed: c.promptUsed,
                            status: c.status, createdAt: c.createdAt,
                            likeCount: max(0, c.likeCount - 1),
                            authorName: c.authorName, authorAvatarUrl: c.authorAvatarUrl,
                            duration: c.duration
                        )
                    }
                } else {
                    state.likedContentIds.insert(contentId)
                    if let idx = state.contents.firstIndex(where: { $0.id == contentId }) {
                        let c = state.contents[idx]
                        state.contents[idx] = ContentItem(
                            id: c.id, userId: c.userId, roomId: c.roomId,
                            fileUrl: c.fileUrl, promptUsed: c.promptUsed,
                            status: c.status, createdAt: c.createdAt,
                            likeCount: c.likeCount + 1,
                            authorName: c.authorName, authorAvatarUrl: c.authorAvatarUrl,
                            duration: c.duration
                        )
                    }
                }
                state.errorMessage = SupabaseError.from(error).localizedDescription
                return .none

            case .generateButtonTapped:
                guard state.authState.isAuthenticated else {
                    state.$showAuthViewTrigger.withLock { $0 = true }
                    return .none
                }
                state.destination = .generate(GenerateFeature.State(room: state.room))
                return .none

            case let .destination(.presented(.generate(.delegate(.generationRequested(roomId, contentType, prompt))))):
                // Generate 画面を閉じて、AppFeature に生成リクエストを中継
                state.destination = nil
                return .send(.delegate(.generationRequested(
                    roomId: roomId,
                    contentType: contentType,
                    prompt: prompt
                )))

            case .destination(.presented(.imageHistory(.delegate(.dismissed)))):
                // 履歴シートを閉じる
                state.destination = nil
                return .none

            case .destination:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    // MARK: - Private

    private func loadContents(state: inout State) -> Effect<Action> {
        state.loadState = .loading
        state.errorMessage = nil
        let roomId = state.room.id
        let contentType = state.room.contentType
        return .run { send in
            await send(.contentsResponse(
                Result { try await contentRepository.fetchContents(roomId, contentType) }
            ))
        }
        .cancellable(id: CancelID.loadContents, cancelInFlight: true)
    }
}

extension RoomDetailFeature.Destination.State: Equatable {}
