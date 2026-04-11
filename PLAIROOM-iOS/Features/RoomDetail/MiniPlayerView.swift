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
                if isGenerating {
                    // 生成中
                    ProgressView()
                        .controlSize(.small)
                    Text("生成中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if pendingCount > 0 {
                    // 確認待ち
                    Image(systemName: "photo.stack")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("生成完了")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(pendingCount)件の確認待ち")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
}
