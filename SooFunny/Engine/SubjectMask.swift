import CoreVideo
import Vision

/// Finds the main subject of a photo (people, pets, objects) with Apple's on-device
/// subject-lifting model. It ships with iOS, so it works offline.
enum SubjectMask {
    /// One flag per pixel, true for the subject. Nil when there is no clear subject
    /// or the model isn't available (for example in some simulators).
    static func compute(for image: PixelImage) -> [Bool]? {
        guard let cgImage = image.makeCGImage() else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              !observation.allInstances.isEmpty,
              let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances,
                                                                      from: handler)
        else { return nil }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent32Float,
              let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let maskWidth = CVPixelBufferGetWidth(buffer), maskHeight = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)

        var mask = [Bool](repeating: false, count: image.pixelCount)
        var subjectPixels = 0
        for y in 0..<image.height {
            let row = (base + (y * maskHeight / image.height) * rowBytes).assumingMemoryBound(to: Float.self)
            for x in 0..<image.width where row[x * maskWidth / image.width] > 0.5 {
                mask[y * image.width + x] = true
                subjectPixels += 1
            }
        }
        // A subject that fills almost nothing or almost everything doesn't help.
        let fraction = Double(subjectPixels) / Double(image.pixelCount)
        return (0.005...0.95).contains(fraction) ? mask : nil
    }
}
