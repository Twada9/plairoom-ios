//
//  RoomDetailFeatureTests.swift
//  PLAIROOM-iOSTests
//

import ComposableArchitecture
import Dependencies
import Testing
@testable import PLAIROOM_iOS

@Suite("RoomDetailFeature Tests")
struct RoomDetailFeatureTests {

    // MARK: - Test Data

    private let mockRoom = Room(
        id: "room-1",
        title: "Test Room",
        description: "Test Description",
        basePrompt: "Test Prompt",
        roomType: "type1",
        contentType: .image,
        createdAt: "2026-03-20T00:00:00Z"
    )

    private let mockContents = [
        ContentItem(
            id: "content-1",
            userId: "user-1",
            roomId: "room-1",
            fileUrl: "https://example.com/1.jpg",
            promptUsed: "prompt 1",
            status: .completed,
            createdAt: "2026-03-20T01:00:00Z",
            likeCount: 5,
            authorName: "Author 1",
            authorAvatarUrl: "https://example.com/avatar1.jpg",
            duration: nil
        ),
        ContentItem(
            id: "content-2",
            userId: "user-2",
            roomId: "room-1",
            fileUrl: "https://example.com/2.jpg",
            promptUsed: "prompt 2",
            status: .completed,
            createdAt: "2026-03-20T02:00:00Z",
            likeCount: 3,
            authorName: "Author 2",
            authorAvatarUrl: "https://example.com/avatar2.jpg",
            duration: nil
        )
    ]

    // MARK: - Initial State & LoadContents Flow

    @Test("onAppear: loading状態でコンテンツとlikedStatusを取得すること")
    func testOnAppearLoadsContentsAndLikedStatus() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents

        let store = TestStore(initialState: RoomDetailFeature.State(room: mockRoom)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in mockContents }
            $0.contentRepository.isLiked = { @Sendable (id: String, _: ContentType) in
                return id == "content-1"
            }
        }

        await store.send(.onAppear)

        await store.receive(\.contentsResponse.success) {
            $0.loadState = .idle
            $0.contents = mockContents
        }

        await store.receive(\.likedStatusResponse.success) {
            $0.likedContentIds = ["content-1"]
        }
    }

    @Test("onAppear: idle状態では何もしないこと")
    func testOnAppearFromIdleDoesNothing() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: mockContents
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in
                Issue.record("fetchContents should not be called")
                return []
            }
        }

        await store.send(.onAppear)
    }

    @Test("contentsResponse(.failure): loadFailedに遷移しエラーメッセージを設定すること")
    func testContentsResponseFailure() async {
        let mockRoom = self.mockRoom

        let store = TestStore(initialState: RoomDetailFeature.State(room: mockRoom)) {
            RoomDetailFeature()
        }

        struct TestError: Error {}

        await store.send(.contentsResponse(.failure(TestError()))) {
            $0.loadState = .loadFailed
        }

        #expect(store.state.errorMessage != nil)
    }

    @Test("retryTapped: loadingに遷移してコンテンツを再取得すること")
    func testRetryTapped() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in mockContents }
            $0.contentRepository.isLiked = { _, _ in false }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.contentsResponse.success) {
            $0.loadState = .idle
            $0.contents = mockContents
        }

        await store.receive(\.likedStatusResponse.success) {
            $0.likedContentIds = []
        }
    }

    @Test("cancelErrorTapped: idleに遷移しエラーメッセージをクリアすること")
    func testCancelErrorTapped() async {
        let mockRoom = self.mockRoom

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomDetailFeature()
        }

        await store.send(.cancelErrorTapped) {
            $0.loadState = .idle
            $0.errorMessage = nil
        }
    }

    // MARK: - Like Button (Optimistic Update)

    @Test("likeButtonTapped: いいね追加時の楽観的更新と成功時の処理")
    func testLikeButtonTappedAddsLike() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: mockContents,
            likedContentIds: []
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.likeContent = { _, _ in }
        }

        let content = mockContents[0]

        await store.send(.likeButtonTapped(content)) {
            $0.likingContentIds = ["content-1"]
            $0.likedContentIds = ["content-1"]
            $0.contents[0] = ContentItem(
                id: content.id,
                userId: content.userId,
                roomId: content.roomId,
                fileUrl: content.fileUrl,
                promptUsed: content.promptUsed,
                status: content.status,
                createdAt: content.createdAt,
                likeCount: 6, // 5 + 1
                authorName: content.authorName,
                authorAvatarUrl: content.authorAvatarUrl,
                duration: content.duration
            )
        }

        await store.receive { action in
            guard case .likeResponse(.success, "content-1", true) = action else { return false }
            return true
        } assert: {
            $0.likingContentIds = []
        }
    }

    @Test("likeButtonTapped: いいね解除時の楽観的更新とlikeCountが0未満にならないこと")
    func testLikeButtonTappedRemovesLike() async {
        let mockRoom = self.mockRoom

        let contentWithZeroLikes = ContentItem(
            id: "content-3",
            userId: "user-3",
            roomId: "room-1",
            fileUrl: "https://example.com/3.jpg",
            promptUsed: "prompt 3",
            status: .completed,
            createdAt: "2026-03-20T03:00:00Z",
            likeCount: 0,
            authorName: "Author 3",
            authorAvatarUrl: nil,
            duration: nil
        )

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [contentWithZeroLikes],
            likedContentIds: ["content-3"]
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.unlikeContent = { _, _ in }
        }

        await store.send(.likeButtonTapped(contentWithZeroLikes)) {
            $0.likingContentIds = ["content-3"]
            $0.likedContentIds = []
            $0.contents[0] = ContentItem(
                id: contentWithZeroLikes.id,
                userId: contentWithZeroLikes.userId,
                roomId: contentWithZeroLikes.roomId,
                fileUrl: contentWithZeroLikes.fileUrl,
                promptUsed: contentWithZeroLikes.promptUsed,
                status: contentWithZeroLikes.status,
                createdAt: contentWithZeroLikes.createdAt,
                likeCount: 0, // max(0, 0 - 1) = 0
                authorName: contentWithZeroLikes.authorName,
                authorAvatarUrl: contentWithZeroLikes.authorAvatarUrl,
                duration: contentWithZeroLikes.duration
            )
        }

        await store.receive { action in
            guard case .likeResponse(.success, "content-3", false) = action else { return false }
            return true
        } assert: {
            $0.likingContentIds = []
        }
    }

    @Test("likeButtonTapped: 通信中の同じコンテンツへの重複タップが無視されること")
    func testLikeButtonTappedIgnoresDuplicateTaps() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents
        let firstContent = mockContents[0]

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: mockContents,
            likedContentIds: [],
            likingContentIds: ["content-1"]
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.likeContent = { _, _ in
                Issue.record("likeContent should not be called")
            }
        }

        await store.send(.likeButtonTapped(firstContent))
    }

    // MARK: - Like Response (Rollback)

    @Test("likeResponse(.failure): いいね追加失敗時にロールバックされること")
    func testLikeResponseFailureRollsBackLike() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents
        let content = mockContents[0]
        let secondContent = mockContents[1]

        let modifiedContent = ContentItem(
            id: content.id,
            userId: content.userId,
            roomId: content.roomId,
            fileUrl: content.fileUrl,
            promptUsed: content.promptUsed,
            status: content.status,
            createdAt: content.createdAt,
            likeCount: 6, // already incremented
            authorName: content.authorName,
            authorAvatarUrl: content.authorAvatarUrl,
            duration: content.duration
        )

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [modifiedContent, secondContent],
            likedContentIds: ["content-1"],
            likingContentIds: ["content-1"]
        )) {
            RoomDetailFeature()
        }

        struct TestError: Error {}

        await store.send(.likeResponse(.failure(TestError()), contentId: "content-1", isLiking: true)) {
            $0.likingContentIds = []
            $0.likedContentIds = []
            $0.contents[0] = ContentItem(
                id: content.id,
                userId: content.userId,
                roomId: content.roomId,
                fileUrl: content.fileUrl,
                promptUsed: content.promptUsed,
                status: content.status,
                createdAt: content.createdAt,
                likeCount: 5, // 6 - 1, rollback
                authorName: content.authorName,
                authorAvatarUrl: content.authorAvatarUrl,
                duration: content.duration
            )
        }

        #expect(store.state.errorMessage != nil)
    }

    @Test("likeResponse(.failure): ロールバック時もlikeCountが0未満にならないこと")
    func testLikeResponseFailureRollbackDoesNotGoBelowZero() async {
        let mockRoom = self.mockRoom

        let contentWithZeroLikes = ContentItem(
            id: "content-3",
            userId: "user-3",
            roomId: "room-1",
            fileUrl: "https://example.com/3.jpg",
            promptUsed: "prompt 3",
            status: .completed,
            createdAt: "2026-03-20T03:00:00Z",
            likeCount: 0,
            authorName: "Author 3",
            authorAvatarUrl: nil,
            duration: nil
        )

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [contentWithZeroLikes],
            likedContentIds: [],
            likingContentIds: ["content-3"]
        )) {
            RoomDetailFeature()
        }

        struct TestError: Error {}

        await store.send(.likeResponse(.failure(TestError()), contentId: "content-3", isLiking: true)) {
            $0.likingContentIds = []
            $0.likedContentIds = []
            $0.contents[0] = ContentItem(
                id: contentWithZeroLikes.id,
                userId: contentWithZeroLikes.userId,
                roomId: contentWithZeroLikes.roomId,
                fileUrl: contentWithZeroLikes.fileUrl,
                promptUsed: contentWithZeroLikes.promptUsed,
                status: contentWithZeroLikes.status,
                createdAt: contentWithZeroLikes.createdAt,
                likeCount: 0, // max(0, 0 - 1) = 0
                authorName: contentWithZeroLikes.authorName,
                authorAvatarUrl: contentWithZeroLikes.authorAvatarUrl,
                duration: contentWithZeroLikes.duration
            )
        }

        #expect(store.state.errorMessage != nil)
    }

    @Test("likeResponse(.failure): SupabaseErrorが適切に変換されること")
    func testLikeResponseFailureConvertsSupabaseError() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents
        let content = mockContents[0]
        let secondContent = mockContents[1]

        let modifiedContent = ContentItem(
            id: content.id,
            userId: content.userId,
            roomId: content.roomId,
            fileUrl: content.fileUrl,
            promptUsed: content.promptUsed,
            status: content.status,
            createdAt: content.createdAt,
            likeCount: 6,
            authorName: content.authorName,
            authorAvatarUrl: content.authorAvatarUrl,
            duration: content.duration
        )

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [modifiedContent, secondContent],
            likedContentIds: ["content-1"],
            likingContentIds: ["content-1"]
        )) {
            RoomDetailFeature()
        }

        let supabaseError = SupabaseError.networkError(message: "Network connection failed")

        await store.send(.likeResponse(.failure(supabaseError), contentId: "content-1", isLiking: true)) {
            $0.likingContentIds = []
            $0.likedContentIds = []
            $0.contents[0] = ContentItem(
                id: content.id,
                userId: content.userId,
                roomId: content.roomId,
                fileUrl: content.fileUrl,
                promptUsed: content.promptUsed,
                status: content.status,
                createdAt: content.createdAt,
                likeCount: 5,
                authorName: content.authorName,
                authorAvatarUrl: content.authorAvatarUrl,
                duration: content.duration
            )
            $0.errorMessage = "Network Error: Network connection failed"
        }
    }

    // MARK: - Generate Button & Delegate

    @Test("generateButtonTapped: 正しいroomを含むdelegateアクションを発行すること")
    func testGenerateButtonTapped() async {
        let mockRoom = self.mockRoom

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle
        )) {
            RoomDetailFeature()
        }

        await store.send(.generateButtonTapped)

        await store.receive { action in
            guard case .delegate(.generateTapped(let room)) = action else { return false }
            return room == mockRoom
        }
    }

    // MARK: - CancelID

    @Test("onAppear: loadContentsのCancelIDが正しく機能すること")
    func testLoadContentsCancelID() async {
        let mockRoom = self.mockRoom
        let mockContents = self.mockContents

        let store = TestStore(initialState: RoomDetailFeature.State(room: mockRoom)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in
                try await Task.sleep(for: .seconds(10))
                return mockContents
            }
            $0.contentRepository.isLiked = { _, _ in false }
        }

        await store.send(.onAppear)

        // 2回目の呼び出しで最初のリクエストがキャンセルされること
        await store.send(.onAppear) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.contentsResponse.success) {
            $0.loadState = .idle
            $0.contents = mockContents
        }

        await store.receive(\.likedStatusResponse.success) {
            $0.likedContentIds = []
        }
    }
}
