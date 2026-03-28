//
//  GenerateView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

struct GenerateView: View {
    @Bindable var store: StoreOf<GenerateFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ルーム情報
                    roomInfoSection

                    // プロンプト入力
                    promptSection

                    // エラー表示
                    if let msg = store.failureReason {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }

                    // 送信ボタン
                    Button {
                        store.send(.submitButtonTapped)
                    } label: {
                        HStack {
                            if store.contentStatus == .generating {
                                ProgressView().tint(.white)
                            }
                            Text(store.contentStatus == .generating ? "生成中..." : "生成する")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.contentStatus == .generating)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .navigationTitle("AI生成")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(store.contentStatus == .generating)
            .alert("ログインが必要です", isPresented: $store.showLoginAlert) {
                Button("ログイン") {
                    store.send(.loginButtonTapped)
                }
                Button("閉じる", role: .cancel) {
                    store.send(.dismissLoginAlert)
                }
            } message: {
                Text("この機能を使用するにはログインが必要です")
            }
        }
    }

    // MARK: - Sections

    private var roomInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ルーム").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: store.room.contentType == .image ? "photo" : "music.note")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.room.title).font(.headline)
                    Text(store.room.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プロンプト").font(.caption).foregroundStyle(.secondary)
            Text("ベースプロンプト: \(store.room.basePrompt)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            TextEditor(text: $store.promptText)
                .frame(minHeight: 120)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if store.promptText.isEmpty {
                        Text("ベースプロンプトに追加したい内容を入力...")
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(EdgeInsets(top: 18, leading: 14, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    GenerateView(
        store: Store(
            initialState: GenerateFeature.State(
                room: Room(
                    id: "1",
                    title: "夏の風景バトル",
                    description: "AIで夏の風景を生成して競おう",
                    basePrompt: "summer landscape, photorealistic",
                    roomType: "battle",
                    contentType: .image,
                    createdAt: "2026-03-14T00:00:00Z"
                )
            )
        ) {
            GenerateFeature()
        }
    )
}
