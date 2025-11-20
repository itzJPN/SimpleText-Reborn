//
//  ContentView.swift
//  SimpleText
//
//  Created by ItzJPN on 11/20/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: SimpleTextDocument

    var body: some View {
        AttributedTextView(attributedText: $document.attributedText)
            .focusedValue(\.currentTextEditorActions, contextActions)
    }

    // Provide a lightweight object that forwards to the AttributedTextView's coordinator via Binding update.
    // Here, we create a proxy that mutates the document's attributedText directly using selection-aware actions
    // implemented in AttributedTextView.Coordinator. To keep it simple, we expose actions through the view itself.
    private var contextActions: TextEditorActionsProxy {
        TextEditorActionsProxy(binding: $document.attributedText)
    }
}

// A proxy that finds the first responder NSTextView and applies actions.
// This keeps ContentView simple without leaking Coordinator references.
final class TextEditorActionsProxy: TextEditorActions {
    @Binding var attributedText: NSAttributedString

    init(binding: Binding<NSAttributedString>) {
        self._attributedText = binding
    }

    private func currentTextView() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    func applyFontFamily(_ family: String) {
        guard let tv = currentTextView(), let storage = tv.textStorage else { return }
        let mutable = NSMutableAttributedString(attributedString: storage)
        let range = tv.selectedRange()
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let newFont = NSFont(name: family, size: oldFont.pointSize) ?? NSFont.systemFont(ofSize: oldFont.pointSize)
            mutable.addAttribute(.font, value: newFont, range: subRange)
        }
        storage.setAttributedString(mutable)
        attributedText = mutable
    }

    func applyFontSize(_ size: CGFloat) {
        guard let tv = currentTextView(), let storage = tv.textStorage else { return }
        let mutable = NSMutableAttributedString(attributedString: storage)
        let range = tv.selectedRange()
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let newFont = NSFontManager.shared.convert(oldFont, toSize: size)
            mutable.addAttribute(.font, value: newFont, range: subRange)
        }
        storage.setAttributedString(mutable)
        attributedText = mutable
    }

    func toggleBold() {
        guard let tv = currentTextView(), let storage = tv.textStorage else { return }
        let mutable = NSMutableAttributedString(attributedString: storage)
        let range = tv.selectedRange()
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let isBold = oldFont.fontDescriptor.symbolicTraits.contains(.bold)
            let finalFont: NSFont = isBold
                ? NSFontManager.shared.convert(oldFont, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(oldFont, toHaveTrait: .boldFontMask)
            mutable.addAttribute(.font, value: finalFont, range: subRange)
        }
        storage.setAttributedString(mutable)
        attributedText = mutable
    }

    func toggleItalic() {
        guard let tv = currentTextView(), let storage = tv.textStorage else { return }
        let mutable = NSMutableAttributedString(attributedString: storage)
        let range = tv.selectedRange()
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let isItalic = oldFont.fontDescriptor.symbolicTraits.contains(.italic)
            let finalFont: NSFont = isItalic
                ? NSFontManager.shared.convert(oldFont, toNotHaveTrait: .italicFontMask)
                : NSFontManager.shared.convert(oldFont, toHaveTrait: .italicFontMask)
            mutable.addAttribute(.font, value: finalFont, range: subRange)
        }
        storage.setAttributedString(mutable)
        attributedText = mutable
    }

    func toggleUnderline() {
        guard let tv = currentTextView(), let storage = tv.textStorage else { return }
        let mutable = NSMutableAttributedString(attributedString: storage)
        let range = tv.selectedRange()
        var hasUnderline = false
        mutable.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
            if let style = value as? NSNumber, style.intValue != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }
        let newValue: Any = hasUnderline ? 0 : NSUnderlineStyle.single.rawValue
        mutable.addAttribute(.underlineStyle, value: newValue, range: range)
        storage.setAttributedString(mutable)
        attributedText = mutable
    }
}

#Preview {
    // Start with plain text default
    let doc = SimpleTextDocument()
    return ContentView(document: .constant(doc))
}

