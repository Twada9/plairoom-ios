//
//  RoomListView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

// MARK: - RoomListView

struct RoomListView: View {
    @Bindable var store: StoreOf<RoomListFeature>

    var body: some View {
        NavigationStack {
            Group {
                switch store.loadState {
                case .loading:
                    loadingView
                case .loadFailed:
                    errorView()
                case .idle:
                    roomListContent
                }
            }
            .navigationTitle("ルーム")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("ルームを読み込み中...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("読み込みに失敗しました")
                    .font(.headline)
                if let message = store.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            VStack(spacing: 12) {
                Button {
                    store.send(.retryTapped)
                } label: {
                    Text("再試行")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    store.send(.cancelErrorTapped)
                } label: {
                    Text("キャンセル")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Room List

    private var roomListContent: some View {
        Group {
            if store.rooms.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.rooms) { room in
                            Button(action: {
                                store.send(.roomTapped(room))
                            }, label: {
                                RoomCard(room: room)
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    store.send(.retryTapped)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("ルームがありません")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - RoomCard

private struct RoomCard: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(room.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                contentTypeBadge
            }

            HStack(spacing: 8) {
                roomTypeBadge
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var contentTypeBadge: some View {
        let (icon, color): (String, Color) = room.contentType == .image
            ? ("photo", .blue)
            : ("music.note", .purple)
        return Label(room.contentType == .image ? "画像" : "音楽", systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var roomTypeBadge: some View {
        let label = switch room.roomType {
        case "free": "フリー"
        case "battle": "バトル"
        case "quiz": "クイズ"
        case "collaboration": "コラボ"
        default: room.roomType
        }
        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    RoomListView(
        store: Store(
            initialState: RoomListFeature.State(
                loadState: .idle,
                rooms: [
                    Room(
                        id: "1",
                        title: "夏の風景を描こう",
                        description: "AIで夏らしい風景画を生成して競い合おう",
                        basePrompt: "beautiful summer landscape",
                        roomType: "battle",
                        contentType: .image,
                        createdAt: "2026-03-14T00:00:00Z"
                    ),
                    Room(
                        id: "2",
                        title: "ジャズセッション",
                        description: "AIで即興ジャズを生成しよう",
                        basePrompt: "smooth jazz improvisation",
                        roomType: "free",
                        contentType: .music,
                        createdAt: "2026-03-13T00:00:00Z"
                    ),
                ]
            )
        ) {
            RoomListFeature()
        }
    )
}
