//
//  ThumbnailService.swift
//  Hackers
//
//  Created by Weiran Zhang on 15/06/2019.
//  Copyright © 2019 Glass Umbrella. All rights reserved.
//

import Cache
import LinkPresentation

class ThumbnailService {
    var storage: Storage<UIImage>?

    init() {
        let diskConfig = DiskConfig(
            name: "ThumbnailCache",
            expiry: .seconds(60 * 60 * 24 * 7 * 6),
            maxSize: 0,
            directory: nil,
            protectionType: FileProtectionType.none
        )
        storage = try? Storage(
            diskConfig: diskConfig,
            memoryConfig: MemoryConfig(),
            transformer: TransformerFactory.forImage()
        )
    }

    public func thumbnail(for url: URL, completion: @escaping (Result<UIImage>) -> Void) {
        guard let storage = self.storage else { return }

        storage.async.object(forKey: url.absoluteString) { result in
            switch result {
            case .value(let image):
                completion(.value(image))
            case .error:
                DispatchQueue.main.async {
                    self.fetchThumbnail(for: url, completion: completion)
                }
            }
        }
    }

    private func fetchThumbnail(for url: URL, completion: @escaping (Result<UIImage>) -> Void) {
        let metadataProvider = LPMetadataProvider()
        metadataProvider.startFetchingMetadata(for: url) { (metadata, error) in
            if error == nil, let metadata = metadata, let imageProvider = metadata.iconProvider {
                imageProvider.loadItem(forTypeIdentifier: "public.png", options: nil) { (item, error) in
                    // swiftlint:disable force_cast
                    if error == nil, let item = item, let image = UIImage(data: item as! Data) {
                        let smallImage = self.resize(image: image, size: CGSize(width: 180, height: 180))
                        try? self.storage?.setObject(smallImage, forKey: url.absoluteString)
                        completion(.value(image))
                    } else {
                        completion(.error(error ?? StorageError.notFound))
                    }
                }
            } else {
                completion(.error(error ?? StorageError.notFound))
            }
        }
    }

    private func resize(image: UIImage, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(origin: CGPoint.zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
