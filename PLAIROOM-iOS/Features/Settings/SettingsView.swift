//
//  SettingsView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                if store.isAuthenticated {
                    // ── ログイン済み ──────────────────────────
                    accountSection
                    planSection
                    linksSection
                    logoutSection
                } else {
                    // ── ゲスト ────────────────────────────────
                    guestSection
                    linksSection
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .disabled(store.isRequesting)
            .overlay {
                if store.isRequesting {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white).scaleEffect(1.5)
                            Text("処理中...").foregroundStyle(.white).font(.subheadline)
                        }
                    }
                }
            }
            .alert("ログアウト", isPresented: $store.showLogoutConfirmation) {
                Button("ログアウト", role: .destructive) {
                    store.send(.logoutConfirmed)
                }
                Button("キャンセル", role: .cancel) {
                    store.send(.logoutCancelled)
                }
            } message: {
                Text("ログアウトしますか？")
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - ゲストセクション

    private var guestSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text("ゲストとして利用中")
                        .font(.headline)
                    Text("投稿・AI生成にはログインが必要です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    store.send(.loginButtonTapped)
                } label: {
                    Text("ログイン / 新規登録")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - アカウントセクション

    private var accountSection: some View {
        Section("アカウント") {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    if !store.userName.isEmpty {
                        Text(store.userName).font(.headline)
                    }
                    Text(store.userEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - プランセクション

    private var planSection: some View {
        Section("プラン") {
            HStack {
                Label(store.isPremium ? "プレミアム" : "無料プラン",
                      systemImage: store.isPremium ? "crown.fill" : "person.fill")
                    .foregroundStyle(store.isPremium ? .yellow : .primary)
                Spacer()
                if !store.isPremium {
                    Text("アップグレード")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    // MARK: - リンクセクション（ゲスト・ログイン共通）

    private var linksSection: some View {
        Section {
            Link(destination: URL(string: "https://example.com/privacy")!) {
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://example.com/terms")!) {
                Label("利用規約", systemImage: "doc.text")
            }
        }
    }

    // MARK: - ログアウトセクション

    private var logoutSection: some View {
        Section {
            if let msg = store.errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button(role: .destructive) {
                store.send(.logoutButtonTapped)
            } label: {
                HStack {
                    Spacer()
                    Text("ログアウト")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ゲスト") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(isAuthenticated: false)
        ) {
            SettingsFeature()
        }
    )
}

#Preview("ログイン済み") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(
                isAuthenticated: true,
                userName: "テストユーザー",
                userEmail: "test@example.com",
                isPremium: false
            )
        ) {
            SettingsFeature()
        }
    )
}
