//
//  AttributedTextView.swift
//  SimpleText
//
//  Created by ItzJPN on 11/20/25.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif


protocol TextEditorActions {
    func applyFontFamily(_ family: String)
    func applyFontSize(_ size: CGFloat)
    func toggleBold()
    func toggleItalic()
    func toggleUnderline()
}

struct CurrentTextEditorActionsKey: FocusedValueKey {
    typealias Value = TextEditorActions
}

extension FocusedValues {
    var currentTextEditorActions: TextEditorActions? {
        get { self[CurrentTextEditorActionsKey.self] }
        set { self[CurrentTextEditorActionsKey.self] = newValue }
    }
}

struct AttributedTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString

    final class Coordinator: NSObject, NSTextViewDelegate, TextEditorActions {
        var parent: AttributedTextView
        weak var textView: NSTextView?

        init(parent: AttributedTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.attributedText = tv.textStorage?.copy() as? NSAttributedString ?? NSAttributedString()
        }

        // MARK: - Actions
        private func applyAttributesToSelection(_ block: (NSMutableAttributedString, NSRange) -> Void) {
            guard let tv = textView,
                  let storage = tv.textStorage
            else { return }

            tv.undoManager?.beginUndoGrouping()
            let mutable = NSMutableAttributedString(attributedString: storage)
            var range = tv.selectedRange()
            if range.length == 0 {
                // No selection: apply to typing attributes (future typed text)
                // and expand to current word as a convenience
                var typingAttrs = tv.typingAttributes
                block(mutable, NSRange(location: range.location, length: 0)) // no-op into mutable
                // Rebuild typing attributes from current font
                if let font = typingAttrs[.font] as? NSFont {
                    // Keep font; block will set later via tv.typingAttributes update
                    typingAttrs[.font] = font
                }
                tv.typingAttributes = typingAttrs
                tv.undoManager?.endUndoGrouping()
                return
            }

            // Normalize range to bounds
            range.location = max(0, min(range.location, mutable.length))
            range.length = max(0, min(range.length, mutable.length - range.location))

            block(mutable, range)

            storage.setAttributedString(mutable)
            tv.setSelectedRange(range)
            tv.undoManager?.endUndoGrouping()
            parent.attributedText = mutable
        }

        func applyFontFamily(_ family: String) {
            applyAttributesToSelection { mutable, range in
                mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    let newFont = NSFont(name: family, size: oldFont.pointSize) ?? NSFont.systemFont(ofSize: oldFont.pointSize)
                    mutable.addAttribute(.font, value: newFont, range: subRange)
                }
            }
        }

        func applyFontSize(_ size: CGFloat) {
            applyAttributesToSelection { mutable, range in
                mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    let newFont = NSFontManager.shared.convert(oldFont, toSize: size)
                    mutable.addAttribute(.font, value: newFont, range: subRange)
                }
            }
        }

        func toggleBold() {
            applyAttributesToSelection { mutable, range in
                mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    let newFont = NSFontManager.shared.convert(oldFont, toHaveTrait: .boldFontMask)
                    // If already bold, toggle off
                    let finalFont: NSFont
                    if oldFont.fontDescriptor.symbolicTraits.contains(.bold) {
                        finalFont = NSFontManager.shared.convert(oldFont, toNotHaveTrait: .boldFontMask)
                    } else {
                        finalFont = newFont
                    }
                    mutable.addAttribute(.font, value: finalFont, range: subRange)
                }
            }
        }

        func toggleItalic() {
            applyAttributesToSelection { mutable, range in
                mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    let isItalic = oldFont.fontDescriptor.symbolicTraits.contains(.italic)
                    let finalFont: NSFont
                    if isItalic {
                        finalFont = NSFontManager.shared.convert(oldFont, toNotHaveTrait: .italicFontMask)
                    } else {
                        finalFont = NSFontManager.shared.convert(oldFont, toHaveTrait: .italicFontMask)
                    }
                    mutable.addAttribute(.font, value: finalFont, range: subRange)
                }
            }
        }

        func toggleUnderline() {
            applyAttributesToSelection { mutable, range in
                var hasUnderline = false
                mutable.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                    if let style = value as? NSNumber, style.intValue != 0 {
                        hasUnderline = true
                        stop.pointee = true
                    }
                }
                let newValue: Any = hasUnderline ? 0 : NSUnderlineStyle.single.rawValue
                mutable.addAttribute(.underlineStyle, value: newValue, range: range)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        scroll.autohidesScrollers = true

        let tv = NSTextView()
        tv.isRichText = true
        tv.allowsUndo = true
        tv.isEditable = true
        tv.isSelectable = true
        tv.usesFindBar = true
        tv.allowsDocumentBackgroundColorChange = false
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.delegate = context.coordinator
        tv.string = ""
        tv.textStorage?.setAttributedString(attributedText)

        // Default typing attributes based on current document content if empty
        if attributedText.length == 0 {
            let defaultFont = NSFont(name: "Geneva", size: 12) ?? NSFont.systemFont(ofSize: 12)
            tv.typingAttributes[.font] = defaultFont
        }

        context.coordinator.textView = tv

        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = (nsView.documentView as? NSTextView) else { return }
        // Avoid resetting if unchanged to preserve selection/undo
        if tv.attributedString() != attributedText {
            tv.textStorage?.setAttributedString(attributedText)
        }
        context.coordinator.textView = tv

        // Expose actions for the currently focused editor
        DispatchQueue.main.async {
            // SwiftUI sets focused values during updates; we cannot set them here directly.
            // The ContentView will set focusedValue(\.currentTextEditorActions, coordinator)
        }
    }
}

