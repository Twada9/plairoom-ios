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
        description: "Description",
        basePrompt: "Prompt",
        roomType: "free",
        contentType: .image,
        createdAt: "2026-03-20T00:00:00Z"
    )

    private let mockContent = ContentItem(
        id: "content-1",
        userId: "user-1",
        roomId: "room-1",
        fileUrl: "https://example.com/image.jpg",
        promptUsed: "A test prompt",
        status: .completed,
        createdAt: "2026-03-20T00:00:00Z",
        likeCount: 0,
        authorName: "User",
        authorAvatarUrl: nil,
        duration: nil
    )

    // MARK: - Initial State Tests

    @Test("初期状態が正しく設定されること")
    func testInitialState() {
        let state = RoomDetailFeature.State(room: mockRoom)

        #expect(state.loadState == .loading)
        #expect(state.contents.isEmpty)
        #expect(state.likedContentIds.isEmpty)
        #expect(state.likingContentIds.isEmpty)
        #expect(state.errorMessage == nil)
    }

    // MARK: - loadContents Success Tests

    @Test("onAppear: loading状態でfetchContentsが呼ばれ、idleに遷移すること")
    func testOnAppearTriggersFetch() async {
        let store = TestStore(initialState: RoomDetailFeature.State(room: mockRoom)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in [self.mockContent] }
            $0.contentRepository.isLiked = { _, _ in false }
        }

        await store.send(.onAppear)

        await store.receive(\.contentsResponse.success) {
            $0.loadState = .idle
            $0.contents = [self.mockContent]
        }

        await store.receive(\.likedStatusResponse.success)
    }

    @Test("onAppear: idle状態では何もしないこと")
    func testOnAppearFromIdleDoesNothing() async {
        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [mockContent]
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

    @Test("onAppear: loadFailed状態から再ロードしてidleに遷移すること")
    func testOnAppearFromLoadFailedRetries() async {
        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .loadFailed,
            errorMessage: "Previous error"
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in [self.mockContent] }
            $0.contentRepository.isLiked = { _, _ in false }
        }

        await store.send(.onAppear) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.contentsResponse.success) {
            $0.loadState = .idle
            $0.contents = [self.mockContent]
        }

        await store.receive(\.likedStatusResponse.success)
    }

    // MARK: - loadContents Failure Tests

    @Test("contentsResponse(.failure): loadStateがloadFailedになること")
    func testLoadContentsFailureSetsLoadFailed() async {
        struct TestError: Error {}

        let store = TestStore(initialState: RoomDetailFeature.State(room: mockRoom)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in throw TestError() }
        }

        await store.send(.onAppear)

        await store.receive(\.contentsResponse.failure) {
            $0.loadState = .loadFailed
            $0.errorMessage = TestError().localizedDescription
        }
    }

    @Test("contentsResponse(.failure): errorMessageが設定されること")
    func testLoadContentsFailureSetsErrorMessage() async {
        struct TestError: Error {}

        let store = TestStore(initialState: RoomDetailFeature.State(room: mockRoom)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in throw TestError() }
        }

        await store.send(.onAppear)

        await store.receive(\.contentsResponse.failure) {
            $0.loadState = .loadFailed
            $0.errorMessage = TestError().localizedDescription
        }

        #expect(store.state.errorMessage != nil)
    }

    // MARK: - retryTapped Tests

    @Test("retryTapped: loadFailedからloadingに遷移してリトライが成功すること")
    func testRetryTappedSuccess() async {
        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in [self.mockContent] }
            $0.contentRepository.isLiked = { _, _ in false }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.contentsResponse.success) {
            $0.loadState = .idle
            $0.contents = [self.mockContent]
        }

        await store.receive(\.likedStatusResponse.success)
    }

    @Test("retryTapped: リトライが失敗した場合にloadFailedに遷移すること")
    func testRetryTappedFailure() async {
        struct TestError: Error {}

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .loadFailed,
            errorMessage: "Previous error"
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.fetchContents = { _, _ in throw TestError() }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.contentsResponse.failure) {
            $0.loadState = .loadFailed
            $0.errorMessage = TestError().localizedDescription
        }
    }

    // MARK: - cancelErrorTapped Tests

    @Test("cancelErrorTapped: loadFailedからidleに遷移すること")
    func testCancelErrorTappedTransitionsToIdle() async {
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

    // MARK: - Like Optimistic Update Tests

    @Test("likeButtonTapped: いいね追加の楽観的更新後にサーバー通信が成功すること")
    func testLikeButtonTappedSuccess() async {
        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [mockContent],
            likedContentIds: []
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.likeContent = { _, _ in }
        }

        await store.send(.likeButtonTapped(mockContent)) {
            $0.likingContentIds = ["content-1"]
            $0.likedContentIds = ["content-1"]
            $0.contents = [ContentItem(
                id: "content-1",
                userId: "user-1",
                roomId: "room-1",
                fileUrl: "https://example.com/image.jpg",
                promptUsed: "A test prompt",
                status: .completed,
                createdAt: "2026-03-20T00:00:00Z",
                likeCount: 1,
                authorName: "User",
                authorAvatarUrl: nil,
                duration: nil
            )]
        }

        await store.receive(\.likeResponse) {
            $0.likingContentIds = []
        }
    }

    @Test("likeButtonTapped: いいね追加が失敗した場合に楽観的更新が巻き戻されること")
    func testLikeButtonTappedRollback() async {
        struct LikeError: Error, LocalizedError {
            var errorDescription: String? { "Like failed" }
        }

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [mockContent],
            likedContentIds: []
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.likeContent = { _, _ in throw LikeError() }
        }

        await store.send(.likeButtonTapped(mockContent)) {
            $0.likingContentIds = ["content-1"]
            $0.likedContentIds = ["content-1"]
            $0.contents = [ContentItem(
                id: "content-1",
                userId: "user-1",
                roomId: "room-1",
                fileUrl: "https://example.com/image.jpg",
                promptUsed: "A test prompt",
                status: .completed,
                createdAt: "2026-03-20T00:00:00Z",
                likeCount: 1,
                authorName: "User",
                authorAvatarUrl: nil,
                duration: nil
            )]
        }

        await store.receive(\.likeResponse) {
            $0.likingContentIds = []
            $0.likedContentIds = []
            $0.contents = [self.mockContent]
            $0.errorMessage = SupabaseError.from(LikeError()).localizedDescription
        }
    }

    // MARK: - Unlike Optimistic Update Tests

    @Test("likeButtonTapped: いいね解除の楽観的更新後にサーバー通信が成功すること")
    func testUnlikeButtonTappedSuccess() async {
        let likedContent = ContentItem(
            id: "content-1",
            userId: "user-1",
            roomId: "room-1",
            fileUrl: "https://example.com/image.jpg",
            promptUsed: "A test prompt",
            status: .completed,
            createdAt: "2026-03-20T00:00:00Z",
            likeCount: 1,
            authorName: "User",
            authorAvatarUrl: nil,
            duration: nil
        )

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [likedContent],
            likedContentIds: ["content-1"]
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.unlikeContent = { _, _ in }
        }

        await store.send(.likeButtonTapped(likedContent)) {
            $0.likingContentIds = ["content-1"]
            $0.likedContentIds = []
            $0.contents = [ContentItem(
                id: "content-1",
                userId: "user-1",
                roomId: "room-1",
                fileUrl: "https://example.com/image.jpg",
                promptUsed: "A test prompt",
                status: .completed,
                createdAt: "2026-03-20T00:00:00Z",
                likeCount: 0,
                authorName: "User",
                authorAvatarUrl: nil,
                duration: nil
            )]
        }

        await store.receive(\.likeResponse) {
            $0.likingContentIds = []
        }
    }

    @Test("likeButtonTapped: いいね解除が失敗した場合に楽観的更新が巻き戻されること")
    func testUnlikeButtonTappedRollback() async {
        struct UnlikeError: Error, LocalizedError {
            var errorDescription: String? { "Unlike failed" }
        }

        let likedContent = ContentItem(
            id: "content-1",
            userId: "user-1",
            roomId: "room-1",
            fileUrl: "https://example.com/image.jpg",
            promptUsed: "A test prompt",
            status: .completed,
            createdAt: "2026-03-20T00:00:00Z",
            likeCount: 1,
            authorName: "User",
            authorAvatarUrl: nil,
            duration: nil
        )

        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [likedContent],
            likedContentIds: ["content-1"]
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.unlikeContent = { _, _ in throw UnlikeError() }
        }

        await store.send(.likeButtonTapped(likedContent)) {
            $0.likingContentIds = ["content-1"]
            $0.likedContentIds = []
            $0.contents = [ContentItem(
                id: "content-1",
                userId: "user-1",
                roomId: "room-1",
                fileUrl: "https://example.com/image.jpg",
                promptUsed: "A test prompt",
                status: .completed,
                createdAt: "2026-03-20T00:00:00Z",
                likeCount: 0,
                authorName: "User",
                authorAvatarUrl: nil,
                duration: nil
            )]
        }

        await store.receive(\.likeResponse) {
            $0.likingContentIds = []
            $0.likedContentIds = ["content-1"]
            $0.contents = [likedContent]
            $0.errorMessage = SupabaseError.from(UnlikeError()).localizedDescription
        }
    }

    // MARK: - Debounce Tests

    @Test("likeButtonTapped: 通信中の連打は無視されること")
    func testLikeButtonTappedWhileInFlight() async {
        let store = TestStore(initialState: RoomDetailFeature.State(
            room: mockRoom,
            loadState: .idle,
            contents: [mockContent],
            likedContentIds: [],
            likingContentIds: ["content-1"]
        )) {
            RoomDetailFeature()
        } withDependencies: {
            $0.contentRepository.likeContent = { _, _ in
                Issue.record("likeContent should not be called while in flight")
            }
        }

        await store.send(.likeButtonTapped(mockContent))
    }
}
