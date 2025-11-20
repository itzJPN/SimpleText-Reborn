//
//  SimpleTextApp.swift
//  SimpleText
//
//  Created by ItzJPN on 11/20/25.
//

import SwiftUI
import AppKit
import Combine
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var observer: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.removeStandardMenusIfPresent()
        }

        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.removeStandardMenusIfPresent()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func removeStandardMenusIfPresent() {
        guard let mainMenu = NSApp.mainMenu else { return }
        /*removeMenu(named: "View", from: mainMenu)
        removeMenu(named: "Window", from: mainMenu)
        removeMenu(named: "Help", from: mainMenu)*/
    }

    private func removeMenu(named title: String, from mainMenu: NSMenu) {
        while true {
            let index = mainMenu.indexOfItem(withTitle: title)
            if index == -1 { break }
            mainMenu.removeItem(at: index)
        }
    }
}

@main
struct SimpleTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @FocusedValue(\.currentTextEditorActions) private var editorActions
    @StateObject private var speech = SpeechController()
    // Shared relay used to drive Commands menu enablement and speech text
    @StateObject private var relay = DocumentTextRelay(initialText: "")

    var body: some Scene {
        DocumentGroup(newDocument: SimpleTextDocument()) { file in
            ContentView(document: file.$document)
                .environmentObject(relay)
                // Keep relay in sync with document changes
                .onAppear {
                    relay.text = file.document.attributedText.string
                }
                .onChange(of: file.document.attributedText) { newValue in
                    relay.text = newValue.string
                }
        }
        .commands {
            CommandMenu("Font") {
                Button("Chicago")   { editorActions?.applyFontFamily("Chicago") }
                Button("Courier")   { editorActions?.applyFontFamily("Courier") }
                Button("Geneva")    { editorActions?.applyFontFamily("Geneva") }
                Button("Helvetica") { editorActions?.applyFontFamily("Helvetica") }
                Button("Monaco")    { editorActions?.applyFontFamily("Monaco") }
                Button("New York")  { editorActions?.applyFontFamily("New York") }
                Button("Palatino")  { editorActions?.applyFontFamily("Palatino") }
                Button("Symbol")    { editorActions?.applyFontFamily("Symbol") }
                Button("Times")     { editorActions?.applyFontFamily("Times") }
            }
            CommandMenu("Size") {
                Button("9 Point")  { editorActions?.applyFontSize(9)  }
                Button("10 Point") { editorActions?.applyFontSize(10) }
                Button("12 Point") { editorActions?.applyFontSize(12) }
                Button("14 Point") { editorActions?.applyFontSize(14) }
                Button("18 Point") { editorActions?.applyFontSize(18) }
                Button("24 Point") { editorActions?.applyFontSize(24) }
                Button("46 Point") { editorActions?.applyFontSize(46) }
            }
            CommandMenu("Style") {
                Button("Bold")      { editorActions?.toggleBold() }.keyboardShortcut("b", modifiers: [.command])
                Button("Italic")    { editorActions?.toggleItalic() }.keyboardShortcut("i", modifiers: [.command])
                Button("Underline") { editorActions?.toggleUnderline() }.keyboardShortcut("u", modifiers: [.command])
            }
            CommandMenu("Sound") {
                // Pass the shared relay explicitly; Commands cannot see environmentObject from the window content.
                SpeakCommands(speech: speech, relay: relay)
            }
        }
    }
}

// MARK: - Relay to drive Commands with live document text

final class DocumentTextRelay: ObservableObject {
    @Published var text: String
    init(initialText: String) { self.text = initialText }
}

// MARK: - Speak Commands

private struct SpeakCommands: View {
    @ObservedObject var speech: SpeechController
    @ObservedObject var relay: DocumentTextRelay

    private var trimmedText: String {
        relay.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            Button("Speak All") {
                speech.speak(text: trimmedText)
            }
            .keyboardShortcut("h", modifiers: [.command])
            .disabled(trimmedText.isEmpty)

            Button("Stop Speaking") {
                speech.stop()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!speech.isSpeaking)

            Menu("Voices") {
                ForEach(speech.availableVoices, id: \.identifier) { voice in
                    Button {
                        speech.setVoice(voice)
                    } label: {
                        if speech.currentVoice?.identifier == voice.identifier {
                            Label(voice.name, systemImage: "checkmark")
                        } else {
                            Text(voice.name)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Speech Controller (AVFoundation)

final class SpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var currentVoice: AVSpeechSynthesisVoice?

    // Full list of voices available on the system
    let availableVoices: [AVSpeechSynthesisVoice]
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        self.availableVoices = AVSpeechSynthesisVoice.speechVoices()
        super.init()
        synthesizer.delegate = self

        // Prefer a voice named "Fred" if available; else use system default (nil lets the system choose)
        if let fred = availableVoices.first(where: { $0.name == "Fred" }) {
            currentVoice = fred
        } else {
            currentVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }
    }

    func speak(text: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        // Configure utterance
        utterance.voice = currentVoice // nil means system default
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }

    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        DispatchQueue.main.async { [weak self] in
            self?.currentVoice = voice
        }
        // If currently speaking, stop so the new voice will apply on next speak
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            DispatchQueue.main.async { [weak self] in
                self?.isSpeaking = false
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }
}
