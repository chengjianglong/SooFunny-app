import SwiftUI

/// The coloring screen: the picture split into blocks, the crayon box and the tools.
struct ColoringView: View {
    @Bindable var session: ColoringSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // iPad in landscape: tools beside the picture so the picture stays big.
                if sizeClass == .regular && geo.size.width > geo.size.height {
                    HStack(spacing: 16) {
                        CanvasView(session: session)
                        VStack(spacing: 16) {
                            detailPicker
                            ToolBar(session: session, columns: 2)
                            PaletteView(selected: $session.selectedColor, large: true)
                            Spacer(minLength: 0)
                        }
                        .frame(width: 320)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        detailPicker
                            .frame(maxWidth: 480)
                            .padding(.horizontal)
                        CanvasView(session: session)
                            .padding(.horizontal, 12)
                        ToolBar(session: session, columns: 5)
                            .padding(.horizontal, 12)
                        PaletteView(selected: $session.selectedColor, large: sizeClass == .regular)
                    }
                    .padding(.bottom, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label(language.pick("Pictures", "图片"), systemImage: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("SooFunny").font(.headline.weight(.heavy))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let canvas = session.canvas {
                        ShareLink(item: Image(uiImage: canvas),
                                  preview: SharePreview(language.pick("My SooFunny picture", "我的 SooFunny 画"),
                                                        image: Image(uiImage: canvas))) {
                            Label(language.pick("Share", "分享"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { LanguageSwitch() }
            }
        }
        .task { await session.prepare() }
        .onChange(of: session.detail) {
            Task { await session.prepare() }
        }
    }

    /// Block size choice, shown only for photos.
    @ViewBuilder
    private var detailPicker: some View {
        if session.segmentation?.isLineArt == false {
            Picker(language.pick("Block size", "色块大小"), selection: $session.detail) {
                ForEach(SegmentDetail.allCases) { detail in
                    Text(language.pick("\(detail.title) blocks", detail.chineseTitle)).tag(detail)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Shows the colored picture and turns taps and finger strokes into fills.
private struct CanvasView: View {
    let session: ColoringSession
    @State private var dragging = false
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        GeometryReader { geo in
            if let segmentation = session.segmentation, let canvas = session.canvas {
                let rect = fitRect(CGSize(width: segmentation.width, height: segmentation.height), in: geo.size)
                ZStack {
                    Image(uiImage: canvas)
                        .resizable()
                        .interpolation(.high)
                    if session.peek {
                        Image(uiImage: session.source)
                            .resizable()
                            .opacity(0.5)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = Int(value.location.x / rect.width * CGFloat(segmentation.width))
                            let y = Int(value.location.y / rect.height * CGFloat(segmentation.height))
                            session.paint(atX: x, y: y, startingStroke: !dragging)
                            dragging = true
                        }
                        .onEnded { _ in dragging = false }
                )
                .position(x: rect.midX, y: rect.midY)
                .accessibilityLabel("Coloring picture with \(segmentation.regionCount) blocks")
            }
            if session.isProcessing {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text(language.pick("Making blocks…", "正在分色块……")).font(.headline)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func fitRect(_ content: CGSize, in container: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0 else { return .zero }
        let scale = min(container.width / content.width, container.height / content.height)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
}

private struct ToolBar: View {
    @Bindable var session: ColoringSession
    let columns: Int
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    /// Tool names are short, so in Bilingual the Chinese goes on a second line.
    private func name(_ english: String, _ chinese: String) -> String {
        language.pick(english, chinese, separator: "\n")
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ToolButton(title: name("Undo", "撤销"), systemImage: "arrow.uturn.backward", tint: .blue) { session.undo() }
                .disabled(!session.canUndo)
            ToolButton(title: name("Magic", "魔法"), systemImage: "wand.and.stars", tint: .purple) { session.surprise() }
            ToolButton(title: name("Real", "真实"), systemImage: "photo", tint: .orange) { session.realColors() }
            ToolButton(title: session.peek ? name("Hide", "隐藏") : name("Peek", "偷看"), systemImage: session.peek ? "eye.slash" : "eye",
                       tint: .teal) { session.peek.toggle() }
            ToolButton(title: name("Clear", "清除"), systemImage: "trash", tint: .red) { session.clear() }
        }
        .disabled(session.segmentation == nil)
    }
}

private struct ToolButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3.weight(.bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }
}

/// The crayon box. Scrolls sideways on iPhone, wraps on iPad.
private struct PaletteView: View {
    @Binding var selected: RGBA
    let large: Bool

    private var customColor: Binding<Color> {
        Binding(get: { Color(uiColor: selected.uiColor) },
                set: { selected = RGBA(UIColor($0)) })
    }

    var body: some View {
        let size: CGFloat = large ? 54 : 44
        Group {
            if large {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: size + 8), spacing: 8)], spacing: 10) {
                    swatches(size: size)
                }
                .frame(maxWidth: 900)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) { swatches(size: size) }
                        .padding(8)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func swatches(size: CGFloat) -> some View {
        ForEach(Palette.crayons, id: \.self) { color in
            Button { selected = color } label: {
                Circle()
                    .fill(Color(uiColor: color.uiColor))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .overlay(Circle().stroke(selected == color ? Color.primary : .clear, lineWidth: 3).padding(-4))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .scaleEffect(selected == color ? 1.1 : 1)
                    .animation(.spring(duration: 0.2), value: selected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Crayon")
        }
        Button { selected = .white } label: {
            Image(systemName: "eraser.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.gray)
                .frame(width: size, height: size)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(selected == .white ? Color.primary : .gray.opacity(0.3), lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Eraser")
        ColorPicker("More colors", selection: customColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: size, height: size)
            .scaleEffect(large ? 1.6 : 1.3)
    }
}
