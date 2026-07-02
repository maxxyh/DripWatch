import SwiftUI

/// The photo(s) to open full-screen. Carrying an array + a start index lets one presentation
/// handle a single shot or a swipeable gallery — bag surfaces and latte-art brew photos share it.
struct PreviewPhoto: Identifiable, Equatable {
    let id = UUID()
    let datas: [Data]
    let index: Int

    init(datas: [Data], index: Int = 0) {
        self.datas = datas
        self.index = index
    }

    /// Convenience for the common single-photo case.
    init(data: Data) {
        self.datas = [data]
        self.index = 0
    }
}

/// A full-screen image viewer. One photo shows on its own; several become a paged gallery. Each
/// page pinches to zoom, drags to pan when zoomed, double-taps to toggle, and swipes down (or the
/// ✕) to dismiss. Black-backed and chrome-light so the photo is the whole story.
struct PhotoViewer: View {
    let datas: [Data]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(datas: [Data], startIndex: Int = 0) {
        self.datas = datas
        self.startIndex = startIndex
        _selection = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if datas.count <= 1 {
                ZoomableImage(data: datas.first ?? Data(), onDismiss: { dismiss() })
            } else {
                TabView(selection: $selection) {
                    ForEach(Array(datas.enumerated()), id: \.offset) { i, data in
                        ZoomableImage(data: data, onDismiss: { dismiss() }).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            overlay
        }
        .statusBarHidden()
    }

    private var overlay: some View {
        VStack {
            HStack {
                if datas.count > 1 {
                    Text("\(selection + 1) / \(datas.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityLabel("Photo \(selection + 1) of \(datas.count)")
                }
                Spacer()
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.top, Theme.Space.s)
            Spacer()
        }
    }
}

/// A single pinch-zoom / pan / double-tap image, with swipe-down-to-dismiss at 1×.
private struct ZoomableImage: View {
    let data: Data
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { _ in
            Group {
                if let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale * pinch)
                        .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                        .gesture(magnification)
                        .simultaneousGesture(panOrDismiss)
                        .onTapGesture(count: 2) { toggleZoom() }
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scale)
                        .accessibilityLabel("Photo. Double tap to zoom.")
                } else {
                    Text("Couldn’t load photo").foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .updating($pinch) { value, state, _ in state = value }
            .onEnded { value in
                scale = min(max(scale * value, 1), maxScale)
                if scale <= 1 { offset = .zero }
            }
    }

    /// Pans when zoomed in; a downward swipe at 1× dismisses.
    private var panOrDismiss: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                if scale > 1 { state = value.translation }
            }
            .onEnded { value in
                if scale > 1 {
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                } else if value.translation.height > 120 {
                    Haptics.tap()
                    onDismiss()
                }
            }
    }

    private func toggleZoom() {
        Haptics.select()
        if scale > 1 { scale = 1; offset = .zero } else { scale = 2.5 }
    }
}

extension View {
    /// Attach a full-screen photo viewer driven by an optional `PreviewPhoto`.
    func photoViewer(_ photo: Binding<PreviewPhoto?>) -> some View {
        fullScreenCover(item: photo) { PhotoViewer(datas: $0.datas, startIndex: $0.index) }
    }
}
