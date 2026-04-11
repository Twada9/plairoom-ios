//
//  ImageHistoryView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

struct ImageHistoryView: View {
    @Bindable var store: StoreOf<ImageHistoryFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブ選択
                Picker("", selection: $store.selectedTab) {
                    Text("画像").tag(ImageHistoryFeature.Tab.image)
                    // Text("音楽").tag(ImageHistoryFeature.Tab.music) // 後回し
                }
                .pickerStyle(.segmented)
                .padding()

                // コンテンツリスト
                if store.items.isEmpty {
                    emptyView
                } else {
                    contentList
                }
            }
            .navigationTitle("生成履歴")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("生成中のコンテンツはありません")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content List

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.items) { item in
                    ImageHistoryCard(
                        item: item,
                        onPostTapped: { store.send(.postTapped(id: item.id)) },
                        onDiscardTapped: { store.send(.discardTapped(id: item.id)) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - ImageHistoryCard

private struct ImageHistoryCard: View {
    let item: ImageContent
    let onPostTapped: () -> Void
    let onDiscardTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // サムネイル
            if let url = URL(string: item.fileUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.tertiarySystemGroupedBackground)
                        .overlay(ProgressView())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // プロンプト
            if !item.promptUsed.isEmpty {
                Text(item.promptUsed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // ステータスバッジ
            statusBadge

            // アクションボタン
            if item.status == .pending {
                HStack(spacing: 12) {
                    Button(action: onDiscardTapped) {
                        Text("破棄")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onPostTapped) {
                        Text("投稿する")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .generating:
            Label("生成中", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        case .pending:
            Label("確認待ち", systemImage: "clock")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        case .posted:
            Label("投稿済み", systemImage: "checkmark.circle")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .discarded:
            Label("破棄済み", systemImage: "xmark.circle")
                .font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(.gray)
                .clipShape(Capsule())
        }
    }
}
