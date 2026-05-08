//
//  ImageDetailView.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import SwiftUI

struct ImageDetailView: View {
    let store: StoreOf<ImageDetailFeature>
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            imageContent
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnificationGesture.simultaneously(with: dragGesture))
                .onTapGesture(count: 2) { handleDoubleTap() }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 60)
            .padding(.leading, 16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    // MARK: - Image

    @ViewBuilder
    private var imageContent: some View {
        if let urlStr = store.item.fileUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    errorPlaceholder
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            errorPlaceholder
        }
    }

    private var errorPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 48))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    withAnimation(.spring) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Double Tap

    private func handleDoubleTap() {
        withAnimation(.spring) {
            if scale > minScale {
                scale = minScale
                lastScale = minScale
                offset = .zero
                lastOffset = .zero
            } else {
                scale = 2.0
                lastScale = 2.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ImageDetailView(
        store: Store(
            initialState: ImageDetailFeature.State(
                item: ContentItem(
                    id: "c1", userId: "u1", roomId: "r1",
                    fileUrl: nil, promptUsed: "夕日が沈む海辺",
                    status: .completed, createdAt: "2026-03-14T00:00:00Z",
                    likeCount: 3, authorName: "テストユーザー",
                    authorAvatarUrl: nil, duration: nil
                )
            )
        ) {
            ImageDetailFeature()
        }
    )
}
