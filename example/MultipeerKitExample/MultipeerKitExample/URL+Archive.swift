import Foundation
import AppleArchive
import System

struct Failure: LocalizedError {
    var errorDescription: String?
    init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

public extension URL {

    func compress(to outputURL: URL, using algorithm: ArchiveCompression = .lzfse) throws {
        var isDir = ObjCBool.init(false)

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            throw Failure("File doesn't exist at \(path)")
        }

        if isDir.boolValue {
            try compressDirectory(to: outputURL, using: algorithm)
        } else {
            try compressFile(to: outputURL, using: algorithm)
        }
    }

}

extension URL {

    func compressFile(to outputURL: URL, using algorithm: ArchiveCompression) throws {
        let sourceFilePath = FilePath(self.path)

        guard let readFileStream = ArchiveByteStream.fileStream(
                path: sourceFilePath,
                mode: .readOnly,
                options: [ ],
                permissions: FilePermissions(rawValue: 0o644))
        else {
            throw Failure("Failed to create file stream for reading")
        }
        defer { try? readFileStream.close() }

        let archiveFilePath = FilePath(outputURL.path)

        guard let writeFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .writeOnly,
                options: [ .create ],
                permissions: FilePermissions(rawValue: 0o644)) else
        {
            throw Failure("Failed to create file stream for writing")
        }
        defer { try? writeFileStream.close() }

        guard let compressStream = ArchiveByteStream.compressionStream(
                using: algorithm,
                writingTo: writeFileStream)
        else {
            throw Failure("Failed to create compression stream")
        }
        defer { try? compressStream.close() }

        do {
            _ = try ArchiveByteStream.process(
                readingFrom: readFileStream,
                writingTo: compressStream
            )
        } catch {
            throw Failure("Failed to compress the file: \(error)")
        }
    }

    func extractFile(to outputURL: URL) throws {
        let archiveFilePath = FilePath(self.path)

        guard let readFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .readOnly,
                options: [ ],
                permissions: FilePermissions(rawValue: 0o644))
        else {
            throw Failure("Failed to create file stream for reading")
        }
        defer { try? readFileStream.close() }

        let destinationFilePath = FilePath(outputURL.path)

        guard let writeFileStream = ArchiveByteStream.fileStream(
                path: destinationFilePath,
                mode: .writeOnly,
                options: [ .create ],
                permissions: FilePermissions(rawValue: 0o644))
        else {
            throw Failure("Failed to create file stream for writing")
        }
        defer { try? writeFileStream.close() }

        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            throw Failure("Failed to create decompression stream")
        }
        defer { try? decompressStream.close() }

        do {
            _ = try ArchiveByteStream.process(
                readingFrom: decompressStream,
                writingTo: writeFileStream
            )
        } catch {
            throw Failure("Extraction failed: \(error)")
        }
    }

    func compressDirectory(to outputURL: URL, using algorithm: ArchiveCompression) throws {
        let archiveFilePath = FilePath(outputURL.path)

        guard let writeFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .writeOnly,
                options: [ .create ],
                permissions: FilePermissions(rawValue: 0o644))
        else {
            throw Failure("Failed to create file stream")
        }

        defer { try? writeFileStream.close() }

        guard let compressStream = ArchiveByteStream.compressionStream(
                using: algorithm,
                writingTo: writeFileStream)
        else {
            throw Failure("Failed to create compression stream")
        }
        defer { try? compressStream.close() }

        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            throw Failure("Failed to create encode stream")
        }
        defer { try? encodeStream.close() }

        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM") else {
            throw Failure("Failed to create key set")
        }

        let source = FilePath(self.path)
        let parent = source.removingLastComponent()

        guard let sourceDirComponent = source.lastComponent else {
            throw Failure("Couldn't find source directory component")
        }

        do {
            try encodeStream.writeDirectoryContents(
                archiveFrom: parent,
                path: FilePath(sourceDirComponent.string),
                keySet: keySet
            )
        } catch {
            throw Failure("Failed to write the archive: \(error)")
        }
    }

    func extractDirectory(to outputURL: URL) throws {
        let archiveFilePath = FilePath(self.path)

        guard let readFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .readOnly,
                options: [ ],
                permissions: FilePermissions(rawValue: 0o644)) else
        {
            throw Failure("Failed to create file stream for reading")
        }
        defer { try? readFileStream.close() }

        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            throw Failure("Failed to create decompression stream")
        }
        defer { try? decompressStream.close() }

        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            throw Failure("Failed to create decode stream")
        }
        defer { try? decodeStream.close() }

        if !FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            } catch {
                throw Failure("Failed to create output directory: \(error)")
            }
        }

        let decompressDestination = FilePath(outputURL.path)

        guard let extractStream = ArchiveStream.extractStream(
            extractingTo: decompressDestination,
            flags: [ .ignoreOperationNotPermitted ]
        )
        else {
            throw Failure("Failed to create extract stream")
        }
        defer { try? extractStream.close() }

        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        } catch {
            throw Failure("Extraction failed: \(error)")
        }
    }

}
