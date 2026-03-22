//
//  SettingsFeatureTests.swift
//  PLAIROOM-iOSTests
//

import ComposableArchitecture
import Dependencies
import Testing
@testable import PLAIROOM_iOS

@Suite("SettingsFeature Tests")
struct SettingsFeatureTests {

    // MARK: - loginButtonTapped Tests

    @Test("loginButtonTapped: delegate(.loginRequested) が送られること")
    func testLoginButtonTappedSendsDelegateLoginRequested() async {
        let store = TestStore(initialState: SettingsFeature.State(isAuthenticated: false)) {
            SettingsFeature()
        }

        await store.send(.loginButtonTapped)
        await store.receive(\.delegate.loginRequested)
    }

    // MARK: - logoutConfirmed Tests

    @Test("logoutConfirmed: isRequesting が true になり、成功時に delegate(.loggedOut) が送られること")
    func testLogoutConfirmedSuccessSendsDelegateLoggedOut() async {
        let store = TestStore(
            initialState: SettingsFeature.State(
                isAuthenticated: true,
                showLogoutConfirmation: true
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.authRepository.signOut = {}
        }

        await store.send(.logoutConfirmed) {
            $0.showLogoutConfirmation = false
            $0.isRequesting = true
            $0.errorMessage = nil
        }

        await store.receive(\.logoutResponse.success) {
            $0.isRequesting = false
        }

        await store.receive(\.delegate.loggedOut)
    }

    @Test("logoutConfirmed: 失敗時に errorMessage が設定されること")
    func testLogoutConfirmedFailureSetsErrorMessage() async {
        let signOutError = SupabaseError.unknown(message: "logout failed")

        let store = TestStore(
            initialState: SettingsFeature.State(
                isAuthenticated: true,
                showLogoutConfirmation: true
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.authRepository.signOut = { throw signOutError }
        }

        await store.send(.logoutConfirmed) {
            $0.showLogoutConfirmation = false
            $0.isRequesting = true
            $0.errorMessage = nil
        }

        await store.receive(\.logoutResponse.failure) {
            $0.isRequesting = false
            $0.errorMessage = SupabaseError.from(signOutError).localizedDescription
        }
    }

    // MARK: - logoutButtonTapped / logoutCancelled Tests

    @Test("logoutButtonTapped: showLogoutConfirmation が true になること")
    func testLogoutButtonTappedShowsConfirmation() async {
        let store = TestStore(initialState: SettingsFeature.State(isAuthenticated: true)) {
            SettingsFeature()
        }

        await store.send(.logoutButtonTapped) {
            $0.showLogoutConfirmation = true
        }
    }

    @Test("logoutCancelled: showLogoutConfirmation が false になること")
    func testLogoutCancelledHidesConfirmation() async {
        let store = TestStore(
            initialState: SettingsFeature.State(
                isAuthenticated: true,
                showLogoutConfirmation: true
            )
        ) {
            SettingsFeature()
        }

        await store.send(.logoutCancelled) {
            $0.showLogoutConfirmation = false
        }
    }
}
