//
//  MiniPlayerView.swift
//  PLAIROOM-iOS
//

import SwiftUI

/// Mini Player（タブバーの上に表示される）
struct MiniPlayerView: View {
    let pendingCount: Int
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
        } else {
            return "生成履歴"
        }
    }

    private var subtitleText: String? {
        if pendingCount > 0 {
            return "\(pendingCount)件の確認待ち"
        }
        return nil
    }
}

#Preview("生成中") {
    MiniPlayerView(pendingCount: 0, isGenerating: true, onTap: {})
}

#Preview("確認待ちあり") {
    MiniPlayerView(pendingCount: 2, isGenerating: false, onTap: {})
}

#Preview("両方") {
    MiniPlayerView(pendingCount: 1, isGenerating: true, onTap: {})
}
