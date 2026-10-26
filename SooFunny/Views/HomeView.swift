import PhotosUI
import SwiftUI

/// The Color page: a playful gallery of pictures to color (animals, faces, people, outdoors and
/// drawings), a Surprise button, and Photos / Camera at the bottom for your own pictures.
struct HomeView: View {
    let onPick: (UIImage) -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var kind: PictureKind = .all
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var loadFailed = false
    @State private var diceSpin = 0.0
    @State private var showPaywall = false
    private let premium = Premium.shared

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BouncyTitle()
                    .padding(.top, 8)
                Text("Pick a picture and color it in!")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                surpriseButton
                kindPicker

                if kind == .all {
                    ForEach(PictureKind.allCases.filter { $0 != .all }) { section in
                        gallerySection(section)
                    }
                } else {
                    gallerySection(kind)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(FunBackground())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    onPick(image)
                } else {
                    loadFailed = true
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if let cameraImage {
                self.cameraImage = nil
                onPick(cameraImage)
            }
        }) {
            CameraPicker { image in
                cameraImage = image
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Couldn't open that picture", isPresented: $loadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try another photo, or pick one from the gallery.")
        }
    }

    // MARK: - Pieces

    private var surpriseButton: some View {
        Button {
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) { diceSpin += 360 }
            let choices = Showcase.pictures(kind).filter { premium.isActive || FreeTier.allows($0) }
            if let picture = (choices.isEmpty ? Showcase.pictures(.drawings) : choices).randomElement(),
               let image = picture.image() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onPick(image) }
            }
        } label: {
            HStack(spacing: 10) {
                Text("🎲")
                    .font(.system(size: 30))
                    .rotationEffect(.degrees(diceSpin))
                Text("Surprise me!")
                    .font(.title2.weight(.heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .frame(minHeight: 60)
            .background(
                LinearGradient(colors: [.pink, .orange, .yellow, .green, .blue, .purple],
                               startPoint: .leading, endPoint: .trailing),
                in: Capsule())
            .shadow(color: .pink.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(SquishButtonStyle())
        .accessibilityLabel("Surprise me with a random picture")
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PictureKind.allCases) { option in
                    let selected = option == kind
                    Button {
                        withAnimation(.spring(duration: 0.3)) { kind = option }
                    } label: {
                        HStack(spacing: 6) {
                            Text(option.emoji)
                            Text(option.title).font(.headline)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(selected ? AnyShapeStyle(option.color.gradient) : AnyShapeStyle(.regularMaterial),
                                    in: Capsule())
                        .overlay(Capsule().stroke(option.color.opacity(selected ? 0 : 0.5), lineWidth: 2))
                    }
                    .buttonStyle(SquishButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }

    private func gallerySection(_ section: PictureKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if kind == .all {
                HStack(spacing: 8) {
                    Text(section.emoji).font(.title)
                    Text(section.title).font(.title2.weight(.heavy))
                    Spacer()
                    Button("See all") { withAnimation(.spring(duration: 0.3)) { kind = section } }
                        .font(.subheadline.weight(.semibold))
                        .tint(section.color)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 200 : 150), spacing: 16)],
                      spacing: 18) {
                ForEach(Array(Showcase.pictures(section).enumerated()), id: \.element.id) { index, picture in
                    let locked = !premium.isActive && !FreeTier.allows(picture)
                    PictureCard(picture: picture, tilt: index.isMultiple(of: 2) ? -2 : 2, locked: locked) {
                        if locked {
                            showPaywall = true
                        } else if let image = picture.image() {
                            onPick(image)
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if premium.isActive {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    BarButtonLabel(title: "Photos", systemImage: "photo.on.rectangle.angled", color: .pink)
                }
                .buttonStyle(SquishButtonStyle())
            } else {
                Button { showPaywall = true } label: {
                    BarButtonLabel(title: "Photos", systemImage: "lock.fill", color: .pink)
                }
                .buttonStyle(SquishButtonStyle())
            }
            if cameraAvailable {
                Button { if premium.isActive { showCamera = true } else { showPaywall = true } } label: {
                    BarButtonLabel(title: "Camera", systemImage: premium.isActive ? "camera.fill" : "lock.fill", color: .blue)
                }
                .buttonStyle(SquishButtonStyle())
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

// MARK: - Fun bits

/// "SooFunny" with each letter gently bouncing in turn.
private struct BouncyTitle: View {
    private let letters = Array("SooFunny")
    private let colors: [Color] = [.pink, .orange, .yellow, .green, .teal, .blue, .indigo, .purple]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 0) {
                ForEach(letters.indices, id: \.self) { i in
                    let phase = t * 3 - Double(i) * 0.45
                    Text(String(letters[i]))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(colors[i % colors.count].gradient)
                        .shadow(color: .black.opacity(0.12), radius: 0, x: 2, y: 3)
                        .offset(y: -max(0, sin(phase)) * 10)
                        .rotationEffect(.degrees(sin(phase) * 4))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("SooFunny")
        .accessibilityAddTraits(.isHeader)
    }
}

/// A picture on a card, like a sticker: slightly tilted, with a colored frame and a label.
private struct PictureCard: View {
    let picture: ShowcasePicture
    let tilt: Double
    let locked: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Color.white
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if locked { PremiumBadge().padding(8) }
                }
                HStack(spacing: 6) {
                    Text(picture.kind.emoji)
                    Text(picture.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(picture.kind.color.gradient)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 4))
            .shadow(color: picture.kind.color.opacity(0.3), radius: 6, y: 4)
            .rotationEffect(.degrees(tilt))
        }
        .buttonStyle(SquishButtonStyle())
        .accessibilityLabel(locked ? "\(picture.title), Premium" : "Color \(picture.title)")
        .task {
            thumbnail = await ThumbnailCache.shared.thumbnail(for: picture)
        }
    }
}

/// Buttons squish a little when pressed.
private struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: configuration.isPressed)
    }
}

/// Soft confetti dots behind the page.
private struct FunBackground: View {
    var body: some View {
        Canvas { context, size in
            var rng = SplitMix64(seed: 42)
            let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]
            for _ in 0..<60 {
                let x = Double(rng.next() % 10_000) / 10_000 * size.width
                let y = Double(rng.next() % 10_000) / 10_000 * size.height
                let r = 4 + Double(rng.next() % 10)
                let color = colors[Int(rng.next() % UInt64(colors.count))]
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(color.opacity(0.18)))
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

private struct BarButtonLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Wraps the system camera. Only shown on devices that have one.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
