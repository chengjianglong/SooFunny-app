import SwiftUI
import UIKit

/// Real photos for the words, bundled as `word-<group>-<word>.jpg` (free to use, from Wikimedia
/// Commons; see `word_photo_credits.json`). Words without a good photo just show their emoji.
enum WordPhotos {
    private static let cache = NSCache<NSString, UIImage>()

    static func fileName(category: String, word: String) -> String {
        "word-\(slug(category))-\(slug(word))"
    }

    static func slug(_ text: String) -> String {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
            .split(separator: "-")
            .joined(separator: "-")
    }

    static func image(category: String, word: String, bundle: Bundle = .main) -> UIImage? {
        let name = fileName(category: category, word: word)
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = bundle.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    /// Who took the word photos.
    static let credits: [PictureCredit] = {
        guard let url = Bundle.main.url(forResource: "word_photo_credits", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PictureCredit].self, from: data)) ?? []
    }()
}

/// The word's real photo with its emoji stuck on the corner like a sticker. Falls back to
/// the emoji tile when the word has no photo.
struct WordPicture: View {
    let category: WordCategory
    let word: WordEntry
    let size: CGFloat
    let tint: Color

    var body: some View {
        if let photo = WordPhotos.image(category: category.name, word: word.text) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                .overlay(RoundedRectangle(cornerRadius: size * 0.2).stroke(.white, lineWidth: max(2, size * 0.03)))
                .shadow(color: .black.opacity(0.15), radius: size * 0.04, y: size * 0.02)
                .overlay(alignment: .bottomTrailing) {
                    if word.emoji != nil {
                        Picture(emoji: word.emoji, word: word.text, size: size * 0.42, tint: tint)
                            .background(.background, in: RoundedRectangle(cornerRadius: size * 0.1))
                            .rotationEffect(.degrees(8))
                            .offset(x: size * 0.1, y: size * 0.08)
                    }
                }
                .padding(.trailing, word.emoji != nil ? size * 0.1 : 0)
                .padding(.bottom, word.emoji != nil ? size * 0.08 : 0)
                .accessibilityHidden(true)
        } else {
            Picture(emoji: word.emoji, word: word.text, size: size, tint: tint)
        }
    }
}
