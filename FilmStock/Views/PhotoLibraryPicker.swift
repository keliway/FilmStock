//
//  PhotoLibraryPicker.swift
//  FilmStock
//
//  Photo library picker and source sheet using PHPicker + unified ImageCropperView
//

import SwiftUI
import PhotosUI

// MARK: - Photo Library Picker Sheet

struct PhotoLibraryPickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoLibraryPickerSheet

        init(_ parent: PhotoLibraryPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.isPresented = false
                return
            }

            let itemProvider = result.itemProvider
            guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
                parent.isPresented = false
                return
            }

            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self else { return }
                let normalized = (object as? UIImage)?.normalizedForCropping()
                DispatchQueue.main.async {
                    if let normalized {
                        self.parent.onImageSelected(normalized)
                    }
                    self.parent.isPresented = false
                }
            }
        }
    }
}

// MARK: - Combined Image Source Picker

struct ImageSourcePicker: View {
    @Binding var finalImage: UIImage?
    @Binding var isPresented: Bool

    private struct CropTarget: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pendingLibraryImage: UIImage?
    @State private var cropTarget: CropTarget?
    @State private var didSelectFinalImage = false

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Button {
                showCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.body)
                        .frame(width: 24)
                    Text("image.takePhoto")
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Button {
                showLibrary = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.body)
                        .frame(width: 24)
                    Text("image.chooseFromLibrary")
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if didSelectFinalImage {
                isPresented = false
            }
        }) {
            CameraView(
                capturedImage: Binding(
                    get: { finalImage },
                    set: { newImage in
                        if let newImage {
                            finalImage = newImage
                            didSelectFinalImage = true
                        }
                    }
                ),
                isPresented: $showCamera
            )
        }
        .sheet(isPresented: $showLibrary, onDismiss: {
            if let image = pendingLibraryImage {
                pendingLibraryImage = nil
                cropTarget = CropTarget(image: image)
            }
        }) {
            PhotoLibraryPickerSheet(
                isPresented: $showLibrary,
                onImageSelected: { image in
                    pendingLibraryImage = image
                }
            )
        }
        .fullScreenCover(item: $cropTarget, onDismiss: {
            if didSelectFinalImage {
                isPresented = false
            }
        }) { target in
            ImageCropperView(
                image: target.image,
                onComplete: { croppedImage in
                    finalImage = croppedImage
                    didSelectFinalImage = true
                    cropTarget = nil
                },
                onCancel: {
                    cropTarget = nil
                }
            )
        }
    }
}

#Preview {
    ImageSourcePicker(finalImage: .constant(nil), isPresented: .constant(true))
}
