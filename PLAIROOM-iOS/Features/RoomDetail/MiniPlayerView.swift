//
//  MiniPlayerView.swift
//  PLAIROOM-iOS
//

import SwiftUI

/// Mini Player（タブバーの上に表示される）
struct MiniPlayerView: View {
    let pendingCount: Int
    let failedCount: Int
    let isGenerating: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                leadingIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if isGenerating {
            ProgressView()
                .controlSize(.small)
        } else if pendingCount > 0 {
            Image(systemName: "photo.stack")
                .font(.title3)
                .foregroundStyle(.blue)
        } else if failedCount > 0 {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        } else {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var titleText: String {
        if isGenerating {
            return "生成中..."
        } else if pendingCount > 0 {
            return "生成完了"
        } else if failedCount > 0 {
            return "生成に失敗"
        } else {
            return "生成履歴"
        }
    }

    private var subtitleText: String? {
        var parts: [String] = []
        if pendingCount > 0 {
            parts.append("\(pendingCount)件の確認待ち")
        }
        if failedCount > 0 {
            parts.append("\(failedCount)件失敗")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }
}

#Preview("生成中") {
    MiniPlayerView(pendingCount: 0, failedCount: 0, isGenerating: true, onTap: {})
}

#Preview("確認待ちあり") {
    MiniPlayerView(pendingCount: 2, failedCount: 0, isGenerating: false, onTap: {})
}

#Preview("失敗あり") {
    MiniPlayerView(pendingCount: 0, failedCount: 1, isGenerating: false, onTap: {})
}

#Preview("全部混在") {
    MiniPlayerView(pendingCount: 2, failedCount: 1, isGenerating: true, onTap: {})
}
