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

    // MARK: - LoadState

    enum LoadState: Equatable {
        case loading
        case idle
        case loadFailed
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
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// 生成画面へ遷移（feature/generate で接続）
            case generateTapped(room: Room)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.contentRepository) var contentRepository

    // MARK: - Body

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard state.loadState != .idle else { return .none }
                return loadContents(state: &state)

            case .contentsResponse(.success(let contents)):
                state.contents = contents
                state.loadState = .idle
                // いいね状態を並行取得
                let ids = contents.map(\.id)
                let contentType = state.room.contentType
                return .run { send in
                    await send(.likedStatusResponse(
                        Result {
                            var liked = Set<String>()
                            for id in ids {
                                if try await contentRepository.isLiked(id, contentType) {
                                    liked.insert(id)
                                }
                            }
                            return liked
                        }
                    ))
                }

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
                return .send(.delegate(.generateTapped(room: state.room)))

            case .delegate:
                return .none
            }
        }
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
    }
}
