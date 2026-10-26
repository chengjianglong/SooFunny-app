import SwiftUI
import UIKit

/// The kinds of built-in pictures on the Color page.
enum PictureKind: String, CaseIterable, Identifiable {
    case all, animals, portraits, people, outdoors, drawings

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .animals: return "Animals"
        case .portraits: return "Faces"
        case .people: return "People"
        case .outdoors: return "Outdoors"
        case .drawings: return "Drawings"
        }
    }

    var emoji: String {
        switch self {
        case .all: return "🌈"
        case .animals: return "🐾"
        case .portraits: return "😄"
        case .people: return "🧒"
        case .outdoors: return "🌳"
        case .drawings: return "✏️"
        }
    }

    var color: Color {
        switch self {
        case .all: return .purple
        case .animals: return .orange
        case .portraits: return .pink
        case .people: return .blue
        case .outdoors: return .green
        case .drawings: return .indigo
        }
    }
}

/// A free photo's source, from `credits.json` (all CC0 from Wikimedia Commons).
struct PictureCredit: Decodable, Identifiable {
    let file: String
    let category: String
    let title: String
    let source: String
    let license: String
    let author: String
    let url: String

    var id: String { file }
}

/// One built-in picture: a bundled photo or a drawing made in code.
struct ShowcasePicture: Identifiable {
    let id: String
    let title: String
    let kind: PictureKind
    private let loader: () -> UIImage?

    init(id: String, title: String, kind: PictureKind, loader: @escaping () -> UIImage?) {
        self.id = id
        self.title = title
        self.kind = kind
        self.loader = loader
    }

    /// The full-size picture, to color.
    func image() -> UIImage? { loader() }
}

enum Showcase {
    static let credits: [PictureCredit] = {
        guard let url = Bundle.main.url(forResource: "credits", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PictureCredit].self, from: data)) ?? []
    }()

    static let all: [ShowcasePicture] = {
        let photos = credits.compactMap { credit -> ShowcasePicture? in
            guard let kind = PictureKind(rawValue: credit.category) else { return nil }
            let name = (credit.file as NSString).deletingPathExtension
            return ShowcasePicture(id: credit.file, title: credit.title, kind: kind) {
                Bundle.main.url(forResource: name, withExtension: "jpg").flatMap { UIImage(contentsOfFile: $0.path) }
            }
        }
        let drawings = SampleArt.all.map { art in
            ShowcasePicture(id: "drawing-\(art.id)", title: art.name, kind: .drawings) { art.image }
        }
        return photos + drawings
    }()

    static func pictures(_ kind: PictureKind) -> [ShowcasePicture] {
        kind == .all ? all : all.filter { $0.kind == kind }
    }
}

/// Small thumbnails, made once off the main thread and kept in memory.
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var images: [String: UIImage] = [:]

    func thumbnail(for picture: ShowcasePicture, size: CGFloat = 420) -> UIImage? {
        if let cached = images[picture.id] { return cached }
        guard let full = picture.image() else { return nil }
        let scale = size / max(full.size.width, full.size.height)
        let thumb = full.preparingThumbnail(of: CGSize(width: full.size.width * scale, height: full.size.height * scale)) ?? full
        images[picture.id] = thumb
        return thumb
    }
}
