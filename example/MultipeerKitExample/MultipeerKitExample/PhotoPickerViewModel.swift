/**
 Copyright © 2023 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
Abstract:
A class that responds to Photos picker events.
*/

import SwiftUI
import PhotosUI

/// A view model that integrates a Photos picker.
@MainActor final class PhotoPickerViewModel: ObservableObject {

    /// A class that manages an image that a person selects in the Photos picker.
    @MainActor final class ImageAttachment: ObservableObject, Identifiable {

        /// Statuses that indicate the app's progress in loading a selected photo.
        enum Status {

            /// A status indicating that the app has requested a photo.
            case loading

            /// A status indicating that the app has loaded a photo.
            case finished(Data, Image)

            /// A status indicating that the photo has failed to load.
            case failed(Error)

            /// Determines whether the photo has failed to load.
            var isFailed: Bool {
                return switch self {
                case .failed: true
                default: false
                }
            }
        }

        /// An error that indicates why a photo has failed to load.
        enum LoadingError: Error {
            case contentTypeNotSupported
        }

        /// A reference to a selected photo in the picker.
        private let pickerItem: PhotosPickerItem

        /// A load progress for the photo.
        @Published var imageStatus: Status?

        /// A textual description for the photo.
        @Published var imageDescription: String = ""

        /// An identifier for the photo.
        nonisolated var id: String {
            pickerItem.identifier
        }

        /// Creates an image attachment for the given picker item.
        init(_ pickerItem: PhotosPickerItem) {
            self.pickerItem = pickerItem
        }

        /// Loads the photo that the picker item features.
        func loadImage() async {
            guard imageStatus == nil || imageStatus?.isFailed == true else {
                return
            }
            imageStatus = .loading
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    imageStatus = .finished(data, Image(uiImage: uiImage))
                } else {
                    throw LoadingError.contentTypeNotSupported
                }
            } catch {
                imageStatus = .failed(error)
            }
        }
    }

    /// An array of items for the picker's selected photos.
    ///
    /// On set, this method updates the image attachments for the current selection.
    @Published var selection = [PhotosPickerItem]() {
        didSet {
            // Update the attachments according to the current picker selection.
            let newAttachments = selection.map { item in
                // Access an existing attachment, if it exists; otherwise, create a new attachment.
                attachmentByIdentifier[item.identifier] ?? ImageAttachment(item)
            }
            // Update the saved attachments array for any new attachments loaded in scope.
            let newAttachmentByIdentifier = newAttachments.reduce(into: [:]) { partialResult, attachment in
                partialResult[attachment.id] = attachment
            }
            // To support asynchronous access, assign new arrays to the instance properties rather than updating the existing arrays.
            attachments = newAttachments
            attachmentByIdentifier = newAttachmentByIdentifier
        }
    }

    /// An array of image attachments for the picker's selected photos.
    @Published var attachments = [ImageAttachment]()

    /// A dictionary that stores previously loaded attachments for performance.
    private var attachmentByIdentifier = [String: ImageAttachment]()
}

/// A extension that handles the situation in which a picker item lacks a photo library.
private extension PhotosPickerItem {
    var identifier: String {
        guard let identifier = itemIdentifier else {
            fatalError("The photos picker lacks a photo library.")
        }
        return identifier
    }
}
