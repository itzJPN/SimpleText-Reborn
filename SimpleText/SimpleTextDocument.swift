//
//  SimpleTextDocument.swift
//  SimpleText
//
//  Created by ItzJPN on 11/20/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// Codable so we can persist the full document. We store the attributed text as RTF data in JSON.
nonisolated struct SimpleTextDocument: FileDocument, Codable {
    // Primary model used by the UI
    var attributedText: NSAttributedString

    // Legacy/plain metadata kept for backward compatibility defaults
    var fontFamily: String
    var pointSize: CGFloat

    enum CodingKeys: String, CodingKey {
        case rtfData    // RTF-encoded attributed text
        case fontFamily // legacy default font family
        case pointSize  // legacy default point size
        case text       // legacy plain text fallback
    }

    init(text: String = "Hello, world!", fontFamily: String = "Geneva", pointSize: CGFloat = 12) {
        self.fontFamily = fontFamily
        self.pointSize = pointSize

        let font = NSFont(name: fontFamily, size: pointSize) ?? NSFont.systemFont(ofSize: pointSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        self.attributedText = NSAttributedString(string: text, attributes: attrs)
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Defaults in case legacy fields are missing
        self.fontFamily = (try? container.decode(String.self, forKey: .fontFamily)) ?? "Geneva"
        self.pointSize = (try? container.decode(CGFloat.self, forKey: .pointSize)) ?? 12

        if let rtf = try? container.decode(Data.self, forKey: .rtfData),
           let attr = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            self.attributedText = attr
            // If we can derive a font from first character, keep metadata in sync
            if attr.length > 0 {
                let attrs = attr.attributes(at: 0, effectiveRange: nil)
                if let font = attrs[.font] as? NSFont {
                    self.fontFamily = font.familyName ?? font.fontName
                    self.pointSize = font.pointSize
                }
            }
            return
        }

        // Legacy fallback: decode plain text + font metadata
        let legacyText = (try? container.decode(String.self, forKey: .text)) ?? "Hello, world!"
        let font = NSFont(name: fontFamily, size: pointSize) ?? NSFont.systemFont(ofSize: pointSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        self.attributedText = NSAttributedString(string: legacyText, attributes: attrs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode RTF representation of attributed text
        let rtf = attributedText.rtfd(from: NSRange(location: 0, length: attributedText.length))
        // Prefer pure RTF if available; otherwise, fall back to RTFD data
        let rtfData: Data
        if let data = attributedText.rtf(from: NSRange(location: 0, length: attributedText.length), documentAttributes: [:]) {
            rtfData = data
        } else if let data = rtf {
            rtfData = data
        } else {
            // As a last resort, encode plain text
            rtfData = (attributedText.string.data(using: .utf8)) ?? Data()
        }
        try container.encode(rtfData, forKey: .rtfData)

        // Also encode basic metadata for convenience
        var family = "Geneva"
        var size: CGFloat = 12
        if attributedText.length > 0 {
            let attrs = attributedText.attributes(at: 0, effectiveRange: nil)
            if let font = attrs[ .font ] as? NSFont {
                family = font.familyName ?? font.fontName
                size = font.pointSize
            }
        }
        try container.encode(family, forKey: .fontFamily)
        try container.encode(size, forKey: .pointSize)

        // Include plain string for human-diff friendliness
        try container.encode(attributedText.string, forKey: .text)
    }

    // MARK: - FileDocument

    static let readableContentTypes = [
        UTType(importedAs: "com.example.plain-text")
    ]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Try decoding as our JSON document first.
        if let decoded = try? JSONDecoder().decode(SimpleTextDocument.self, from: data) {
            self = decoded
            return
        }

        // Fallback: interpret as plain UTF-8 text for backward compatibility.
        if let string = String(data: data, encoding: .utf8) {
            self.init(text: string)
            return
        }

        throw CocoaError(.fileReadCorruptFile)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Encode the document as JSON containing RTF data and metadata
        let data = try JSONEncoder().encode(self)
        return .init(regularFileWithContents: data)
    }
}
