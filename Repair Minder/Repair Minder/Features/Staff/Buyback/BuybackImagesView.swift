//
//  BuybackImagesView.swift
//  Repair Minder
//
//  Package D — buyback image management surface: gallery (view/set-final/
//  delete, cross-platform) plus source-photo upload and AI product-photo
//  generation (#if os(iOS) — camera/PhotosPicker are iOS-only APIs).
//

import SwiftUI
#if os(iOS)
import PhotosUI
import UIKit
#endif

struct BuybackImagesView: View {
    let buybackId: String
    var onImagesChanged: (() -> Void)?

    @StateObject private var viewModel: BuybackImagesViewModel
    @State private var pendingDeleteImage: BuybackImageItem?
    @Environment(\.dismiss) private var dismiss

    #if os(iOS)
    @State private var frontLibraryItem: PhotosPickerItem?
    @State private var backLibraryItem: PhotosPickerItem?
    @State private var showFrontCamera = false
    @State private var showBackCamera = false

    @State private var generateImageType: GenerateImageType = .listingFront
    @State private var generateLibraryItem: PhotosPickerItem?
    @State private var showGenerateCamera = false
    #endif

    init(buybackId: String, onImagesChanged: (() -> Void)? = nil) {
        self.buybackId = buybackId
        self.onImagesChanged = onImagesChanged
        _viewModel = StateObject(wrappedValue: BuybackImagesViewModel(buybackId: buybackId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let imageError = viewModel.imageError {
                        Text(imageError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    galleryGrid

                    #if os(iOS)
                    uploadSection
                    generateSection
                    #else
                    Text("Uploading source photos and generating AI product photos is available on iPhone/iPad.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif
                }
                .padding()
            }
            .navigationTitle("Manage Images")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isBusy { ProgressView() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.isBusy { ProgressView() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
        .task { await viewModel.loadImages() }
        .onDisappear { onImagesChanged?() }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: Binding(
                get: { pendingDeleteImage != nil },
                set: { if !$0 { pendingDeleteImage = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let imageId = pendingDeleteImage?.id {
                    Task { await viewModel.deleteImage(imageId: imageId) }
                }
                pendingDeleteImage = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteImage = nil }
        }
        #if os(iOS)
        .sheet(isPresented: $showFrontCamera) {
            CameraPicker { image in Task { await handlePicked(image, field: "source_front") } }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showBackCamera) {
            CameraPicker { image in Task { await handlePicked(image, field: "source_back") } }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showGenerateCamera) {
            CameraPicker { image in Task { await handleGeneratePicked(image) } }
                .ignoresSafeArea()
        }
        .onChange(of: frontLibraryItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleLibrary(newItem, field: "source_front"); frontLibraryItem = nil }
        }
        .onChange(of: backLibraryItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleLibrary(newItem, field: "source_back"); backLibraryItem = nil }
        }
        .onChange(of: generateLibraryItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleGenerateLibrary(newItem); generateLibraryItem = nil }
        }
        #endif
    }

    // MARK: - Gallery (cross-platform)

    private var galleryGrid: some View {
        Group {
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.images.isEmpty {
                Text("No photos yet").font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.images) { item in
                        galleryTile(item)
                    }
                }
            }
        }
    }

    private func galleryTile(_ item: BuybackImageItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthenticatedImageView(imageId: item.id, width: 300, height: 300)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if item.isFinalValue {
                        Label("Final", systemImage: "checkmark.seal.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.green, in: Capsule())
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                }

            if let imageType = item.imageType, !imageType.isEmpty {
                Text(imageType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.setFinal(imageId: item.id) }
                } label: {
                    Label("Set Final", systemImage: "checkmark.seal")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(item.isFinalValue || viewModel.isBusy)

                Button(role: .destructive) {
                    pendingDeleteImage = item
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy)
            }
        }
        .frame(width: 140)
    }

    #if os(iOS)
    // MARK: - Upload Source Photos (iOS only)

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Source Photos").font(.subheadline.bold())

            HStack(spacing: 12) {
                Menu {
                    Button { showFrontCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                    PhotosPicker(selection: $frontLibraryItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Front Photo", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.isBusy)

                Menu {
                    Button { showBackCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                    PhotosPicker(selection: $backLibraryItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Back Photo", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.isBusy)
            }
        }
    }

    // MARK: - AI Product Photos (iOS only)

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Generate Product Photos").font(.subheadline.bold())
            Text("Uses AI to turn a source photo into a clean listing-ready product photo.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Type", selection: $generateImageType) {
                ForEach(GenerateImageType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                Button { showGenerateCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                PhotosPicker(selection: $generateLibraryItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                Label("Generate from Photo", systemImage: "sparkles")
            }
            .disabled(viewModel.isBusy)
        }
    }

    // MARK: - Picker Handlers (iOS only)

    private func handlePicked(_ image: UIImage, field: String) async {
        guard let payload = PickedImageEncoder.encode(image) else {
            viewModel.imageError = "Couldn't process photo"
            return
        }
        await viewModel.uploadSource(payload, field: field)
    }

    private func handleLibrary(_ item: PhotosPickerItem, field: String) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let payload = PickedImageEncoder.encode(image) else {
            viewModel.imageError = "Couldn't process photo"
            return
        }
        await viewModel.uploadSource(payload, field: field)
    }

    private func handleGeneratePicked(_ image: UIImage) async {
        guard let payload = PickedImageEncoder.encode(image) else {
            viewModel.imageError = "Couldn't process photo"
            return
        }
        await viewModel.generate(front: payload, imageType: generateImageType.rawValue)
    }

    private func handleGenerateLibrary(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let payload = PickedImageEncoder.encode(image) else {
            viewModel.imageError = "Couldn't process photo"
            return
        }
        await viewModel.generate(front: payload, imageType: generateImageType.rawValue)
    }
    #endif
}

#if os(iOS)
/// Target `image_type` for AI-generated product photos (POST /api/buyback/:id/product-photos).
enum GenerateImageType: String, CaseIterable, Identifiable {
    case listingFront = "listing_front"
    case listingBack = "listing_back"
    case listingLifestyle = "listing_lifestyle"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .listingFront: return "Front"
        case .listingBack: return "Back"
        case .listingLifestyle: return "Lifestyle"
        }
    }
}
#endif
