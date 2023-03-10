import UIKit
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    private init() {}
    private let storage = Storage.storage().reference()

    enum StorageError: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
    typealias Completion = (Result<String, Error>) -> Void

    /// Uploads profile picture to Firebase Storage and returns completion with image URL
    func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping Completion) {
        // TODO: Fix it, rather than suppressing it.
        // swiftlint:disable:next unused_closure_parameter
        storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
            guard let strongSelf = self else { return }
            guard error == nil else {
                // failed
                debugPrint("Failed to upload data to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }

            // TODO: Fix it, rather than suppressing it.
            // swiftlint:disable:next unused_closure_parameter
            strongSelf.storage.child("images/\(fileName)").downloadURL { url, error in
                guard let url else {
                    debugPrint("Failed to get download URL")
                    completion(.failure(StorageError.failedToGetDownloadURL))
                    return
                }

                let urlString = url.absoluteString
                debugPrint("Download URL returned: \(urlString)")
                completion(.success(urlString))
            }
        }
    }

    /// Uploads image that will be sent in a conversation message
    public func uploadPhoto(with data: Data, fileName: String, completion: @escaping Completion) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
            guard error == nil else {
                // failed
                debugPrint("Failed to upload data to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }

            self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
                guard let url else {
                    debugPrint("Failed to get download URL")
                    completion(.failure(StorageError.failedToGetDownloadURL))
                    return
                }

                let urlString = url.absoluteString
                debugPrint("Download URL returned: \(urlString)")
                completion(.success(urlString))
            }
        }
    }

    /// Uploads video that will be sent in a conversation message
    public func uploadVideo(with fileURL: URL, fileName: String, completion: @escaping Completion) {
        storage.child("message_videos/\(fileName)").putFile(from: fileURL, metadata: nil) { [weak self] metadata, error in
            guard error == nil else {
                // failed
                debugPrint("Failed to upload video file to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }

            self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
                guard let url else {
                    debugPrint("Failed to get download URL")
                    completion(.failure(StorageError.failedToGetDownloadURL))
                    return
                }

                let urlString = url.absoluteString
                debugPrint("Download URL returned: \(urlString)")
                completion(.success(urlString))
            }
        }
    }

    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        reference.downloadURL { url, error in
            guard let url, error == nil else {
                completion(.failure(StorageError.failedToGetDownloadURL))
                return
            }

            completion(.success(url))
        }
    }
}
