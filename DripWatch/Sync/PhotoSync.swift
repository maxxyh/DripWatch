import CryptoKit
import Foundation
import UIKit

enum PhotoSyncError: Error, Equatable, LocalizedError, Sendable {
    case invalidImage
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The photo data is not a readable image."
        case .jpegEncodingFailed:
            return "The photo could not be encoded as JPEG."
        }
    }
}

struct PreparedPhoto: Equatable, Sendable {
    let data: Data
    let sha256: String
    let path: String
}

enum PhotoSync {
    static let maxPixelDimension = 1_400
    static let jpegQuality: CGFloat = 0.8

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func relativePath(photoID: UUID, sha256: String) -> String {
        "\(photoID.uuidString.lowercased())/\(sha256.lowercased()).jpg"
    }

    static func relativePath(photoID: UUID, data: Data) -> String {
        relativePath(photoID: photoID, sha256: sha256Hex(data))
    }

    static func prepare(data: Data, photoID: UUID) throws -> PreparedPhoto {
        let normalizedJPEG = try normalizedJPEGData(from: data)
        let hash = sha256Hex(normalizedJPEG)
        return PreparedPhoto(
            data: normalizedJPEG,
            sha256: hash,
            path: relativePath(photoID: photoID, sha256: hash)
        )
    }

    /// Decodes, orientation-normalizes, downsizes, and JPEG-encodes without letting UIKit
    /// objects cross the sync boundary. The returned Foundation Data is Sendable.
    static func normalizedJPEGData(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw PhotoSyncError.invalidImage
        }

        let imageSizeInPixels = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        let largestDimension = max(imageSizeInPixels.width, imageSizeInPixels.height)
        guard largestDimension > 0 else {
            throw PhotoSyncError.invalidImage
        }

        let resizeFactor = min(1, CGFloat(maxPixelDimension) / largestDimension)
        let targetSize = CGSize(
            width: max(1, round(imageSizeInPixels.width * resizeFactor)),
            height: max(1, round(imageSizeInPixels.height * resizeFactor))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        guard let jpeg = renderer.jpegData(withCompressionQuality: jpegQuality, actions: { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }) as Data? else {
            throw PhotoSyncError.jpegEncodingFailed
        }

        return jpeg
    }
}
