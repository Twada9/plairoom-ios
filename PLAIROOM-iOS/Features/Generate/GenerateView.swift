//
//  GenerateView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

struct GenerateView: View {
    @Bindable var store: StoreOf<GenerateFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ルーム情報
                roomInfoSection

                // 使用状況バナー（取得できた場合のみ表示）
                if let usage = store.usageStatus, !usage.isPremium {
                    usageBannerSection(usage: usage)
                }

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
                .disabled(store.contentStatus == .generating || isOverLimit)
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle("AI生成")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(store.contentStatus == .generating)
        .onAppear { store.send(.onAppear) }
    }

    private var isOverLimit: Bool {
        guard let usage = store.usageStatus else { return false }
        return usage.remaining <= 0
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

    @ViewBuilder
    private func usageBannerSection(usage: UsageStatus) -> some View {
        VStack(spacing: 12) {
            // 残り回数表示
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本日の残り生成回数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(usage.remaining)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(usage.remaining <= 2 ? .red : .primary)
                        Text("/ \(usage.limit) 回")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // 残り回数ゲージ
                CircularProgressView(
                    value: usage.limit > 0 ? Double(usage.remaining) / Double(usage.limit) : 0
                )
                .frame(width: 44, height: 44)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // リワード広告ボタン（残り視聴回数がある場合のみ表示）
            if usage.rewardRemaining > 0 {
                RewardAdButton(
                    rewardRemaining: usage.rewardRemaining,
                    isLoading: store.isGrantingReward
                ) {
                    // AdMob 実装後は広告視聴→完了コールバックで .rewardEarned を送る
                    // 現在はモックとして直接付与
                    store.send(.rewardEarned)
                }
            } else if usage.remaining <= 0 {
                // 上限かつリワード使い切り
                VStack(spacing: 6) {
                    Text("本日の生成上限に達しました")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("明日0時にリセットされます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プロンプト").font(.caption).foregroundStyle(.secondary)
            Text("ベースプロンプト: \(store.room.basePrompt)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.promptText)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

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

// MARK: - RewardAdButton

private struct RewardAdButton: View {
    let rewardRemaining: Int
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("動画を見て +3回 獲得")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("残り\(rewardRemaining)回視聴可能")
                        .font(.caption2)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(isLoading)
    }
}

// MARK: - CircularProgressView

private struct CircularProgressView: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.separator), lineWidth: 4)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    value > 0.3 ? Color.accentColor : .red,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: value)
        }
    }
}

// MARK: - Preview

#Preview("通常") {
    NavigationStack {
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
                    ),
                    usageStatus: UsageStatus(
                        used: 7, limit: 10, remaining: 3,
                        isPremium: false, rewardRemaining: 2
                    )
                )
            ) {
                GenerateFeature()
            }
        )
    }
}

#Preview("上限近い") {
    NavigationStack {
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
                    ),
                    usageStatus: UsageStatus(
                        used: 10, limit: 10, remaining: 0,
                        isPremium: false, rewardRemaining: 3
                    )
                )
            ) {
                GenerateFeature()
            }
        )
    }
}

#Preview("上限かつリワード使い切り") {
    NavigationStack {
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
                    ),
                    usageStatus: UsageStatus(
                        used: 19, limit: 19, remaining: 0,
                        isPremium: false, rewardRemaining: 0
                    )
                )
            ) {
                GenerateFeature()
            }
        )
    }
}
