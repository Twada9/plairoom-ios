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
                if store.authState.isAuthenticated {
                    // ── ログイン済み ──────────────────────────
                    accountSection
                    planSection
                    linksSection
                    logoutSection
                    deleteAccountSection
                } else {
                    // ── ゲスト ────────────────────────────────
                    guestSection
                    linksSection
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .disabled(store.loadState == .loading)
            .overlay {
                if store.loadState == .loading {
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
            .sheet(
                isPresented: Binding(
                    get: { store.deleteAccountSheet != nil },
                    set: { _ in }
                )
            ) {
                if let confirmation = store.deleteAccountSheet {
                    DeleteAccountSheetView(confirmation: confirmation, store: store)
                }
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
        let isPremium = store.authState == .premium
        return Section("プラン") {
            HStack {
                Label(isPremium ? "プレミアム" : "無料プラン",
                      systemImage: isPremium ? "crown.fill" : "person.fill")
                    .foregroundStyle(isPremium ? .yellow : .primary)
                Spacer()
                if !isPremium {
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

    // MARK: - 退会セクション

    private var deleteAccountSection: some View {
        Section {
            Button(role: .destructive) {
                store.send(.deleteAccountButtonTapped)
            } label: {
                HStack {
                    Spacer()
                    Text("退会する")
                    Spacer()
                }
            }
        } footer: {
            Text("退会するとアカウントおよびすべてのデータが完全に削除されます。この操作は取り消せません。")
        }
    }
}

// MARK: - 退会確認シート

private struct DeleteAccountSheetView: View {
    let confirmation: SettingsFeature.DeleteAccountSheetState
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 警告
                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            "退会するとすべてのデータが完全に削除されます",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.orange)

                        ForEach(
                            ["プロフィール情報", "投稿コンテンツ", "いいね・コメント", "AI利用ログ", "ストレージ上のファイル"],
                            id: \.self
                        ) { item in
                            Label(item, systemImage: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("この操作は取り消せません。")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 12))

                    // パスワード入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("確認のためパスワードを入力してください")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        SecureField("パスワード", text: Binding(
                            get: { store.deleteAccountSheet?.password ?? "" },
                            set: {
                                store.send(
                                    .deleteAccountSheet(.presented(.binding(.set(\.password, $0))))
                                )
                            }
                        ))
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    if case .failed(let message) = confirmation.loadState {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                .padding()
            }
            .navigationTitle("退会確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.send(.deleteAccountSheet(.presented(.cancelTapped)))
                    }
                    .disabled(confirmation.loadState == .loading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.deleteAccountSheet(.presented(.confirmTapped)))
                    } label: {
                        if confirmation.loadState == .loading {
                            ProgressView()
                        } else {
                            Text("退会する")
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(confirmation.loadState == .loading || confirmation.password.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(confirmation.loadState == .loading)
    }
}

// MARK: - Preview

#Preview("ゲスト") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        }
    )
}

#Preview("ログイン済み") {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(
                userName: "テストユーザー",
                userEmail: "test@example.com",
                authState: .standard
            )
        ) {
            SettingsFeature()
        }
    )
}
