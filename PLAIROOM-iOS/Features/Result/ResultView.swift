//
//  ResultView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

struct ResultView: View {
    @Bindable var store: StoreOf<ResultFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // コンテンツプレビュー
                        previewSection

                        // エラー
                        if let msg = store.errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // アクションボタン
                        actionButtons
                    }
                    .padding(20)
                }

                // ローディングオーバーレイ
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
            .navigationTitle("生成結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { store.send(.cancelButtonTapped) }
                        .disabled(store.isRequesting)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 16) {
            if store.room.contentType == .image{
                // 生成完了待ちの場合はプレースホルダー
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.checkmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.tint)
                            Text("画像が生成されました")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .overlay {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36))
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading) {
                                Text("音楽が生成されました")
                                    .font(.subheadline)
                            }
                        }
                    }
            }

            Text("コンテンツ ID: \(store.contentId)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.postButtonTapped)
            } label: {
                Text("投稿する")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isRequesting)

            Button {
                store.send(.retryButtonTapped)
            } label: {
                Text("やり直す")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(store.isRequesting)
        }
    }
}

// MARK: - Preview

#Preview {
    ResultView(
        store: Store(
            initialState: ResultFeature.State(
                contentId: "preview-content-id",
                room: Room(
                    id: "1",
                    title: "夏の風景バトル",
                    description: "AIで夏の風景を生成して競おう",
                    basePrompt: "summer landscape",
                    roomType: "battle",
                    contentType: .image,
                    createdAt: "2026-03-14T00:00:00Z"
                )
            )
        ) {
            ResultFeature()
        }
    )
}
