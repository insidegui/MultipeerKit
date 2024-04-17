import SwiftUI
import MultipeerKit
import PhotosUI

@available(iOS 17.0, *)
@MainActor
final class AirDropViewModel: ObservableObject {

    let transceiver: MultipeerTransceiver
    let remotePeer: Peer

    enum OperationState {
        case idle
        case progress(String, Double?)
        case failure(Error)
        case success(String?, [Image]?)
    }

    var canUpload: Bool {
        switch operationState {
        case .idle, .failure, .success:
            return true
        default:
            return false
        }
    }

    @Published var receivedImages: [Image]? = nil

    @Published private(set) var operationState = OperationState.idle {
        didSet {
            if case .success(_, let images) = operationState {
                self.receivedImages = images
            }
        }
    }

    init(transceiver: MultipeerTransceiver, remotePeer: Peer) {
        self.transceiver = transceiver
        self.remotePeer = remotePeer

        transceiver.receiveResources { [weak self] stream in
            self?.handleReceive(stream)
        }

        #if DEBUG
        if MultipeerDataSource.isSwiftUIPreview {
            self.operationState = .success(nil, [
                Image(.testPhoto1),
                Image(.testPhoto2),
                Image(.testPhoto3),
                Image(.testPhoto4),
            ])
        }
        #endif
    }

    func performUpload(with attachments: [PhotoPickerViewModel.ImageAttachment]) {
        Task {
            do {
                print("Upload requested with \(attachments.count) attachment(s)")

                operationState = .progress("Preparing", nil)

                let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("MKUpload-\(UUID().uuidString)")

                try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)

                for attachment in attachments {
                    guard case .finished(let data, _) = attachment.imageStatus else {
                        print("WARN: Ignoring image that's not been loaded yet")
                        continue
                    }

                    let id = UUID().uuidString
                    let fileURL = temporaryURL
                        .appendingPathComponent(id)
                        .appendingPathExtension("jpg")

                    print("Copying attachment \(id) to \(fileURL.path)")

                    try data.write(to: fileURL, options: .atomic)
                }

                print("All attachments copied, preparing archive")

                let compressedURL = temporaryURL
                    .deletingPathExtension()
                    .appendingPathExtension("aar")

                try temporaryURL.compress(to: compressedURL)

                print("Compressed archive written to \(compressedURL.path)")

                let stream = transceiver.send(compressedURL, to: remotePeer)

                for try await progress in stream {
                    operationState = .progress("Uploading", progress)
                }

                operationState = .success("Finished Uploading", nil)

                do {
                    try FileManager.default.removeItem(at: temporaryURL)
                    try FileManager.default.removeItem(at: compressedURL)
                } catch {
                    print("Cleanup failed: \(error)")
                }
            } catch {
                operationState = .failure(error)
            }
        }
    }

    private func handleReceive(_ stream: MultipeerTransceiver.ResourceEventStream) {
        Task {
            do {
                for try await event in stream {
                    switch event {
                    case .progress(_, let progress):
                        operationState = .progress("Receiving Upload", progress)
                    case .completion(let result):
                        let localArchiveURL = try result.get()

                        let images = try await handleDownloadedArchive(at: localArchiveURL)

                        operationState = .success("Finished Receiving Upload", images)
                    }
                }
            } catch {
                operationState = .failure(error)
            }
        }
    }

    private func handleDownloadedArchive(at url: URL) async throws -> [Image] {
        print("Extracting downloaded archive from \(url.path)")

        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MKDownload-\(UUID().uuidString)")

        try url.extractDirectory(to: temporaryURL)

        print("Extracted to \(temporaryURL.path)")

        guard let enumerator = FileManager.default.enumerator(at: temporaryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: nil) else {
            throw Failure("Couldn't enumerate downloaded files")
        }

        let images: [Image] = enumerator.allObjects
            .compactMap { $0 as? URL }
            .compactMap { url in
                print("- \(url.path)")

                guard let uiImage = UIImage(contentsOfFile: url.path) else {
                    print("WARN: Failed to load image at \(url.path)")
                    return nil
                }

                let image = Image(uiImage: uiImage)

                return image
            }

        try FileManager.default.removeItem(at: temporaryURL)

        print("Successfully extracted \(images.count) image(s)")

        return images
    }

}

@available(iOS 17.0, *)
struct AirDropScreen: View {
    @StateObject private var photoPickerViewModel = PhotoPickerViewModel()
    @StateObject private var viewModel: AirDropViewModel

    init(transceiver: MultipeerTransceiver, peer: Peer) {
        let viewModel = AirDropViewModel(transceiver: transceiver, remotePeer: peer)
        self._viewModel = .init(wrappedValue: viewModel)
    }

    @State private var showingReceivedImages = false

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.canUpload {
                uploader
            }

            switch viewModel.operationState {
            case .idle:
                EmptyView()
            case .success(let message, _):
                if let message {
                    Text(message)
                        .foregroundStyle(.green)
                }
            case .failure(let error):
                Text(String(describing: error))
                    .foregroundStyle(.red)
            case .progress(let message, let fraction):
                VStack {
                    ProgressView(value: fraction)

                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .multilineTextAlignment(.center)
        .onChange(of: viewModel.receivedImages) { images in
            if images != nil {
                self.showingReceivedImages = true
            }
        }
        .onAppear {
            if viewModel.receivedImages != nil {
                self.showingReceivedImages = true
            }
        }
        .inspector(isPresented: .constant(viewModel.canUpload && !showingReceivedImages)) {
            PhotosPicker(
                selection: $photoPickerViewModel.selection,

                // Enable the app to dynamically respond to user adjustments.
                selectionBehavior: .continuousAndOrdered,
                matching: .images,
                preferredItemEncoding: .compatible,
                photoLibrary: .shared()
            ) {
                Text("Select Photos")
            }

            // Configure a half-height Photos picker.
            .photosPickerStyle(.inline)

            // Disable the cancel button for an inline use case.
            .photosPickerDisabledCapabilities(.selectionActions)

            // Hide padding around all edges in the picker UI.
            .photosPickerAccessoryVisibility(.hidden, edges: .all)
            .ignoresSafeArea()
        }
        .overlay {
            if let images = viewModel.receivedImages, showingReceivedImages {
                receivedImagesOverlay(images)
            }
        }
        .animation(.snappy, value: showingReceivedImages)
    }

    @ViewBuilder
    private var uploader: some View {
        if photoPickerViewModel.attachments.isEmpty {
            Text("Select photos to upload")
                .font(.headline)
        }
        ZStack {
            ForEach(photoPickerViewModel.attachments.indices, id: \.self) { i in
                let attachment = photoPickerViewModel.attachments[i]
                ImageAttachmentView(imageAttachment: attachment)
                    .shadow(radius: 10)
                    .rotationEffect(.degrees(Double(i) * ((i % 2 == 0) ? 2.5 : -2.5)))
                    .transition(.scale(scale: 2).combined(with: .opacity))
                    .zIndex(Double(i))
            }
        }
        .padding(.top, 32)
        .animation(.bouncy, value: photoPickerViewModel.attachments.count)

        if !photoPickerViewModel.attachments.isEmpty {
            Button("Upload") {
                viewModel.performUpload(with: photoPickerViewModel.attachments)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func receivedImagesOverlay(_ images: [Image]) -> some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [.init(.adaptive(minimum: 120, maximum: 220), spacing: 16)], spacing: 16) {
                ForEach(images.indices, id: \.self) { i in
                    let image = images[i]
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    viewModel.receivedImages = nil
                    showingReceivedImages = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }

                Text("Received Images")
            }
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .padding(.top)
        }
        .background {
            Rectangle()
                .foregroundStyle(.thinMaterial)
                .ignoresSafeArea()
                .transition(.opacity)
        }
        .transition(.scale(scale: 1.4).combined(with: .opacity))
    }
}

struct ImageAttachmentView: View {

    /// An image that a person selects in the Photos picker.
    @ObservedObject var imageAttachment: PhotoPickerViewModel.ImageAttachment

    /// A container view for the row.
    var body: some View {
        ZStack {
            switch imageAttachment.imageStatus {
            case .finished(_, let image):
                image
                    .resizable()
            case .failed:
                Rectangle()
                    .fill(.tertiary)
                Image(systemName: "exclamationmark.triangle.fill")
            default:
                Rectangle()
                    .fill(.tertiary)
                ProgressView()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task { await imageAttachment.loadImage() }
    }
}


@available(iOS 17.0, *)
#Preview {
    AirDropScreen(transceiver: .example, peer: .mock)
        .environmentObject(MultipeerDataSource.example)
}
