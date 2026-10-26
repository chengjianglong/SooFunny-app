import PhotosUI
import SwiftUI

/// Start screen: pick a photo, snap one with the camera, or choose a built-in drawing.
struct HomeView: View {
    let onPick: (UIImage) -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var loadFailed = false

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("SooFunny")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.pink, .orange, .yellow, .green, .blue, .purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("Pick a picture, then color the blocks!")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                HStack(spacing: 16) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        BigButtonLabel(title: "Photos", systemImage: "photo.on.rectangle.angled", color: .pink)
                    }
                    if cameraAvailable {
                        Button { showCamera = true } label: {
                            BigButtonLabel(title: "Camera", systemImage: "camera.fill", color: .blue)
                        }
                    }
                }
                .frame(maxWidth: 520)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Or try one of these")
                        .font(.title2.weight(.bold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 220 : 150), spacing: 16)], spacing: 16) {
                        ForEach(SampleArt.all) { sample in
                            Button { onPick(sample.image) } label: {
                                VStack(spacing: 8) {
                                    Image(uiImage: sample.image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Text(sample.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color the \(sample.name)")
                        }
                    }
                }
                .frame(maxWidth: 900)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
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
        .alert("Couldn't open that picture", isPresented: $loadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try another photo, or pick one of the drawings.")
        }
    }
}

private struct BigButtonLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .bold))
            Text(title)
                .font(.title3.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 24))
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
