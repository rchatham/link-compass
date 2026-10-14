import AppKit
import LinkCompassCore
import UniformTypeIdentifiers

/// A Share service accepts one complete web URL, never extracts a link from prose.
enum ShareInputLoader {
    static func load(from context: NSExtensionContext?, completion: @escaping (Result<URL, Error>) -> Void) {
        load(inputItems: context?.inputItems ?? [], completion: completion)
    }

    static func load(inputItems: [Any], completion: @escaping (Result<URL, Error>) -> Void) {
        guard inputItems.count == 1, let item = inputItems.first as? NSExtensionItem else {
            completion(.failure(ShareInputError.singleLinkRequired))
            return
        }

        let attachments = item.attachments ?? []
        guard attachments.count <= 1 else {
            completion(.failure(ShareInputError.singleLinkRequired))
            return
        }
        // macOS can deliver shared NSString content as attributed text without
        // attachments. Validate the entire string, never its embedded links.
        guard let provider = attachments.first else {
            guard let text = item.attributedContentText?.string else {
                completion(.failure(ShareInputError.singleLinkRequired))
                return
            }
            do {
                completion(.success(try WebURLValidator.validatedURL(from: text)))
            } catch {
                completion(.failure(error))
            }
            return
        }

        // An advertised URL wins even if loading/validation fails. Do not silently
        // reinterpret an invalid URL representation as a different text payload.
        let isURL = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        let type = isURL ? UTType.url.identifier : UTType.plainText.identifier
        guard isURL || provider.hasItemConformingToTypeIdentifier(type) else {
            completion(.failure(ShareInputError.unsupportedRepresentation))
            return
        }

        provider.loadItem(forTypeIdentifier: type, options: nil) { value, error in
            if let error {
                completion(.failure(error))
                return
            }
            do {
                let url: URL
                if isURL, let suppliedURL = value as? URL {
                    url = try WebURLValidator.validatedURL(suppliedURL)
                } else if let text = value as? String {
                    url = try WebURLValidator.validatedURL(from: text)
                } else if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                    url = try WebURLValidator.validatedURL(from: text)
                } else {
                    throw ShareInputError.unsupportedRepresentation
                }
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

private enum ShareInputError: LocalizedError {
    case singleLinkRequired
    case unsupportedRepresentation

    var errorDescription: String? {
        switch self {
        case .singleLinkRequired:
            return "Share exactly one link or one piece of text containing only a web URL."
        case .unsupportedRepresentation:
            return "This item does not provide a web URL or plain-text URL."
        }
    }
}
