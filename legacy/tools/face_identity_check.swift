import AppKit
import Foundation
import Vision

enum IdentityCheckError: Error, CustomStringConvertible {
    case unreadable(String)
    case noFace(String)
    case noFeaturePrint(String)

    var description: String {
        switch self {
        case .unreadable(let path): return "Bild unlesbar: \(path)"
        case .noFace(let path): return "Kein Gesicht erkannt: \(path)"
        case .noFeaturePrint(let path): return "Kein Feature Print: \(path)"
        }
    }
}

func loadImage(_ path: String) throws -> CGImage {
    guard let image = NSImage(contentsOfFile: path),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { throw IdentityCheckError.unreadable(path) }
    return cgImage
}

func faceCrop(_ image: CGImage, path: String) throws -> CGImage {
    let request = VNDetectFaceRectanglesRequest()
    try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
    guard let face = request.results?.max(by: {
        $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
    }) else { throw IdentityCheckError.noFace(path) }

    let bounds = face.boundingBox
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let faceRect = CGRect(
        x: bounds.minX * width,
        y: (1 - bounds.maxY) * height,
        width: bounds.width * width,
        height: bounds.height * height
    )
    let padding = max(faceRect.width, faceRect.height) * 0.22
    let cropRect = faceRect.insetBy(dx: -padding, dy: -padding)
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        .integral
    guard let crop = image.cropping(to: cropRect) else {
        throw IdentityCheckError.noFace(path)
    }
    return crop
}

func featurePrint(_ path: String) throws -> VNFeaturePrintObservation {
    let image = try faceCrop(loadImage(path), path: path)
    let request = VNGenerateImageFeaturePrintRequest()
    try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
    guard let result = request.results?.first as? VNFeaturePrintObservation else {
        throw IdentityCheckError.noFeaturePrint(path)
    }
    return result
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: face_identity_check reference.png candidate.png [...]\n".utf8))
    exit(2)
}

do {
    let reference = try featurePrint(arguments[0])
    for candidate in arguments.dropFirst() {
        let observation = try featurePrint(candidate)
        var distance: Float = 0
        try reference.computeDistance(&distance, to: observation)
        print(String(format: "%.5f\t%@", distance, candidate))
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
