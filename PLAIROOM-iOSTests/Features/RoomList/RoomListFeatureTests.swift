//
//  RoomListFeatureTests.swift
//  PLAIROOM-iOSTests
//

import ComposableArchitecture
import Dependencies
import Testing
@testable import PLAIROOM_iOS

@Suite("RoomListFeature Tests")
struct RoomListFeatureTests {

    // MARK: - Test Data

    private let mockRooms = [
        Room(
            id: "room-1",
            title: "Test Room 1",
            description: "Description 1",
            basePrompt: "Prompt 1",
            roomType: "type1",
            contentType: "image",
            createdAt: "2026-03-20T00:00:00Z"
        ),
        Room(
            id: "room-2",
            title: "Test Room 2",
            description: "Description 2",
            basePrompt: "Prompt 2",
            roomType: "type2",
            contentType: "music",
            createdAt: "2026-03-21T00:00:00Z"
        )
    ]

    // MARK: - Initial State Tests

    @Test("初期状態が正しく設定されること")
    func testInitialState() {
        let state = RoomListFeature.State()

        #expect(state.loadState == .loading)
        #expect(state.rooms.isEmpty)
        #expect(state.errorMessage == nil)
        #expect(state.selectedRoomID == nil)
    }

    // MARK: - onAppear Tests

    @Test("onAppear: loading状態でloadingになり、fetchRoomsが呼ばれること")
    func testOnAppearFromLoadingState() async {
        let store = TestStore(initialState: RoomListFeature.State(loadState: .loading)) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = { self.mockRooms }
        }

        await store.send(.onAppear)

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }
    }

    @Test("onAppear: idle状態では何もしないこと")
    func testOnAppearFromIdleState() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .idle,
            rooms: mockRooms
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = {
                Issue.record("fetchRooms should not be called")
                return []
            }
        }

        await store.send(.onAppear)
    }

    @Test("onAppear: loadFailed状態でloadingになり、fetchRoomsが呼ばれること")
    func testOnAppearFromLoadFailedState() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Previous error"
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = { self.mockRooms }
        }

        await store.send(.onAppear) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }
    }

    @Test("onAppear: 前回のerrorMessageがクリアされること")
    func testOnAppearClearsErrorMessage() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Previous error"
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = { self.mockRooms }
        }

        await store.send(.onAppear) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }
    }

    // MARK: - roomsResponse Success Tests

    @Test("roomsResponse(.success): rooms配列が正しく更新されること")
    func testRoomsResponseSuccessUpdatesRooms() async {
        let store = TestStore(initialState: RoomListFeature.State(loadState: .loading)) {
            RoomListFeature()
        }

        await store.send(.roomsResponse(.success(mockRooms))) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }
    }

    @Test("roomsResponse(.success): 複数回の成功でroomsが上書きされること")
    func testRoomsResponseSuccessOverwritesRooms() async {
        let firstRooms = [mockRooms[0]]
        let secondRooms = mockRooms

        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .idle,
            rooms: firstRooms
        )) {
            RoomListFeature()
        }

        await store.send(.roomsResponse(.success(secondRooms))) {
            $0.loadState = .idle
            $0.rooms = secondRooms
        }

        #expect(store.state.rooms == secondRooms)
    }

    // MARK: - roomsResponse Failure Tests

    @Test("roomsResponse(.failure): loadState が loadFailed になること")
    func testRoomsResponseFailureSetsLoadFailed() async {
        let store = TestStore(initialState: RoomListFeature.State(loadState: .loading)) {
            RoomListFeature()
        }

        struct TestError: Error {}

        await store.send(.roomsResponse(.failure(TestError()))) {
            $0.loadState = .loadFailed
            $0.errorMessage = "エラーが発生しました。もう一度お試しください。"
        }
    }

    @Test("roomsResponse(.failure): errorMessage が設定されること")
    func testRoomsResponseFailureSetsErrorMessage() async {
        let store = TestStore(initialState: RoomListFeature.State(loadState: .loading)) {
            RoomListFeature()
        }

        struct TestError: Error {}

        await store.send(.roomsResponse(.failure(TestError()))) {
            $0.loadState = .loadFailed
            $0.errorMessage = "エラーが発生しました。もう一度お試しください。"
        }

        #expect(store.state.errorMessage != nil)
    }

    // MARK: - retryTapped Tests

    @Test("retryTapped: loadFailed から loading に遷移すること")
    func testRetryTappedTransitionsToLoading() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = { self.mockRooms }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }
    }

    @Test("retryTapped: 前回のerrorMessageがクリアされること")
    func testRetryTappedClearsErrorMessage() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Previous error"
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = { self.mockRooms }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }
    }

    @Test("retryTapped: fetchRoomsが呼ばれること")
    func testRetryTappedCallsFetchRooms() async {
        var fetchRoomsCalled = false

        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = {
                fetchRoomsCalled = true
                return self.mockRooms
            }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }

        #expect(fetchRoomsCalled)
    }

    // MARK: - cancelErrorTapped Tests

    @Test("cancelErrorTapped: loadFailed から idle に遷移すること")
    func testCancelErrorTappedTransitionsToIdle() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomListFeature()
        }

        await store.send(.cancelErrorTapped) {
            $0.loadState = .idle
            $0.errorMessage = nil
        }
    }

    @Test("cancelErrorTapped: errorMessageがクリアされること")
    func testCancelErrorTappedClearsErrorMessage() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Error message"
        )) {
            RoomListFeature()
        }

        await store.send(.cancelErrorTapped) {
            $0.loadState = .idle
            $0.errorMessage = nil
        }

        #expect(store.state.errorMessage == nil)
    }

    // MARK: - roomTapped Tests

    @Test("roomTapped: selectedRoomIDがタップしたIDになること")
    func testRoomTappedSetsSelectedRoomID() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .idle,
            rooms: mockRooms
        )) {
            RoomListFeature()
        }

        let tappedRoom = mockRooms[0]

        await store.send(.roomTapped(tappedRoom)) {
            $0.selectedRoomID = tappedRoom.id
        }

        #expect(store.state.selectedRoomID == "room-1")
    }

    @Test("roomTapped: 異なるルームをタップすると selectedRoomID が更新されること")
    func testRoomTappedUpdatesSelectedRoomID() async {
        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .idle,
            rooms: mockRooms,
            selectedRoomID: "room-1"
        )) {
            RoomListFeature()
        }

        let secondRoom = mockRooms[1]

        await store.send(.roomTapped(secondRoom)) {
            $0.selectedRoomID = secondRoom.id
        }

        #expect(store.state.selectedRoomID == "room-2")
    }

    // MARK: - Effect Tests

    @Test("onAppear: fetchRoomsが1回だけ呼ばれること")
    func testOnAppearCallsFetchRoomsOnce() async {
        var fetchRoomsCallCount = 0

        let store = TestStore(initialState: RoomListFeature.State(loadState: .loading)) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = {
                fetchRoomsCallCount += 1
                return self.mockRooms
            }
        }

        await store.send(.onAppear)

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }

        #expect(fetchRoomsCallCount == 1)
    }

    @Test("retryTapped: fetchRoomsが1回だけ呼ばれること")
    func testRetryTappedCallsFetchRoomsOnce() async {
        var fetchRoomsCallCount = 0

        let store = TestStore(initialState: RoomListFeature.State(
            loadState: .loadFailed,
            errorMessage: "Error"
        )) {
            RoomListFeature()
        } withDependencies: {
            $0.roomRepository.fetchRooms = {
                fetchRoomsCallCount += 1
                return self.mockRooms
            }
        }

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.errorMessage = nil
        }

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .idle
            $0.rooms = self.mockRooms
        }

        #expect(fetchRoomsCallCount == 1)
    }
}
