//
//  AuthView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

// MARK: - AuthView

struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブ切り替え
                // tabChanged アクションを経由して errorMessage もリセットする
                Picker("", selection: Binding(
                    get: { store.tab },
                    set: { store.send(.tabChanged($0)) }
                )) {
                    Text("ログイン").tag(AuthFeature.Tab.login)
                    Text("新規登録").tag(AuthFeature.Tab.signUp)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)

                // フォーム
                ScrollView {
                    VStack(spacing: 20) {
                        switch store.tab {
                        case .login:
                            loginForm
                        case .signUp:
                            signUpForm
                        }

                        // エラーメッセージ
                        if let errorMessage = store.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 送信ボタン
                        submitButton
                    }
                    .padding()
                }
            }
            .navigationTitle(store.tab == .login ? "ログイン" : "新規登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelButtonTapped)
                    }
                }
            }
            .disabled(store.isRequesting)
            .overlay {
                // ローディングオーバーレイ
                if store.isRequesting {
                    ZStack {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.primary)
                            .scaleEffect(1.5)
                    }
                }
            }
        }
    }

    // MARK: - ログインフォーム

    @ViewBuilder
    private var loginForm: some View {
        VStack(spacing: 16) {
            fieldLabel("メールアドレス")
            TextField("example@mail.com", text: $store.loginEmail)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            fieldLabel("パスワード")
            SecureField("8文字以上", text: $store.loginPassword)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - 新規登録フォーム

    @ViewBuilder
    private var signUpForm: some View {
        VStack(spacing: 16) {
            fieldLabel("ユーザー名")
            TextField("表示名", text: $store.signUpName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            fieldLabel("メールアドレス")
            TextField("example@mail.com", text: $store.signUpEmail)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            fieldLabel("パスワード")
            SecureField("8文字以上", text: $store.signUpPassword)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - 送信ボタン

    private var isSubmitDisabled: Bool {
        switch store.tab {
        case .login:
            return store.loginEmail.isEmpty || store.loginPassword.isEmpty
        case .signUp:
            return store.signUpName.isEmpty || store.signUpEmail.isEmpty || store.signUpPassword.isEmpty
        }
    }

    private var submitButton: some View {
        Button {
            store.send(store.tab == .login ? .loginButtonTapped : .signUpButtonTapped)
        } label: {
            Text(store.tab == .login ? "ログイン" : "登録する")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSubmitDisabled)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
