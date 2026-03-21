//
//  RoomDetailView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

// MARK: - RoomDetailView

struct RoomDetailView: View {
    @Bindable var store: StoreOf<RoomDetailFeature>

    var body: some View {
        NavigationStack {
            Group {
                switch store.loadState {
                case .loading:
                    loadingView
                case .loadFailed:
                    errorView
                case .idle:
                    contentListView
                }
            }
            .navigationTitle(store.room.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.generateButtonTapped)
                    } label: {
                        Label("生成", systemImage: "wand.and.stars")
                    }
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("読み込み中...").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                // TODO: エラー周りをリファクタする。
                Text("読み込みに失敗しました").font(.headline)
                if let msg = store.errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            VStack(spacing: 12) {
                Button { store.send(.retryTapped) } label: {
                    Text("再試行").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button { store.send(.cancelErrorTapped) } label: {
                    Text("キャンセル").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content List

    private var contentListView: some View {
        Group {
            if store.contents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("まだコンテンツがありません").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.contents) { content in
                            ContentCard(
                                content: content,
                                isLiked: store.likedContentIds.contains(content.id),
                                isLiking: store.likingContentIds.contains(content.id),
                                contentType: store.room.contentType,
                                onLikeTapped: { store.send(.likeButtonTapped(content)) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable { store.send(.retryTapped) }
            }
        }
    }
}

// MARK: - ContentCard

private struct ContentCard: View {
    let content: ContentItem
    let isLiked: Bool
    /// 連打防止用。通信中かどうか
    let isLiking: Bool
    let contentType: String
    let onLikeTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // サムネイル / 音楽プレースホルダー
            thumbnailView

            // 投稿者・いいね
            HStack {
                if let name = content.authorName {
                    Label(name, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onLikeTapped) {
                    if isLiking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("\(content.likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(isLiked ? .red : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLiking)
            }

            // プロンプト
            if let prompt = content.promptUsed, !prompt.isEmpty {
                Text(prompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // ステータスバッジ（自分のコンテンツが pending / generating の場合）
            statusBadge
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if contentType == "image" {
            if let urlStr = content.fileUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.tertiarySystemGroupedBackground)
                        .overlay(ProgressView())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 200)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 80)
                .overlay(
                    HStack(spacing: 12) {
                        Image(systemName: "music.note").font(.title2).foregroundStyle(.purple)
                        if let sec = content.duration {
                            Text("\(sec)秒").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                )
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch content.status {
        case .generating:
            Label("生成中", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        case .pending:
            Label("投稿待ち", systemImage: "clock")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        case .failed:
            Label("失敗", systemImage: "xmark.circle")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        case .completed:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    RoomDetailView(
        store: Store(
            initialState: RoomDetailFeature.State(
                room: Room(
                    id: "1",
                    title: "夏の風景バトル",
                    description: "AIで夏の風景を生成して競おう",
                    basePrompt: "summer landscape",
                    roomType: "battle",
                    contentType: "image",
                    createdAt: "2026-03-14T00:00:00Z"
                ),
                loadState: .idle,
                contents: [
                    ContentItem(
                        id: "c1", userId: "u1", roomId: "1",
                        fileUrl: nil, promptUsed: "海辺で夕日が沈む場面",
                        status: .completed, createdAt: "2026-03-14T00:00:00Z",
                        likeCount: 5, authorName: "テストユーザー",
                        authorAvatarUrl: nil, duration: nil
                    )
                ]
            )
        ) {
            RoomDetailFeature()
        }
    )
}
