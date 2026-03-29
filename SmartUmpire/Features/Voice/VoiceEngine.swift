import Foundation
import AVFoundation
internal import Speech
import AudioToolbox
import Combine

let VOICE_DEBUG = true

/// Central speech engine: mic + Apple Speech framework.
/// Own ONE instance at the app root (e.g. ContentView @StateObject).
final class VoiceEngine: ObservableObject {

    // MARK: - Published State

    @Published var isRecording: Bool = false
    @Published var transcript: String = ""
    @Published var liveCaption: String = ""
    @Published var errorMessage: String?

    @Published var speechAuth: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var micAuth: AVAudioSession.RecordPermission = .undetermined

    /// Called once per phrase when SFSpeech gives a final result
    var onUtterance: ((String) -> Void)?

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastNonEmptyPartial: String = ""

    // Silence → finalize logic (not stop)
    private var lastSpeechTime = Date()
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0    // Finalize window

    // MARK: - Init / Deinit
    
    

    init(locale: Locale = Locale(identifier: "en_US")) {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            fatalError("SFSpeechRecognizer not available for locale \(locale.identifier)")
        }
        self.speechRecognizer = recognizer

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
        }
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Permissions

    func requestPermissions(completion: (() -> Void)? = nil) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechAuth = status

                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        self?.micAuth = ok ? .granted : .denied

                        //  If both permissions granted → auto-start
                        if status == .authorized && ok {
                            completion?()
                        }
                    }
                }
            }
        }
    }


    var canRecord: Bool {
        speechAuth == .authorized && micAuth == .granted && speechRecognizer.isAvailable
    }

    // MARK: - Control

    func start() {
        errorMessage = nil

        if !canRecord {
            requestPermissions {
                // Auto-start once permission is granted
                self.start()
            }
            errorMessage = "Microphone/Speech permission required."
            return
        }

        if isRecording {
            return
        }

        do {
            try configureSession()
            try startStream()
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            stop()
            errorMessage = "Start failed: \(error.localizedDescription)"
        }
    }

    func stop(auto: Bool = false) {
        recognitionTask?.finish()
        recognitionTask = nil

        request?.endAudio()
        request = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        silenceTimer?.invalidate()
        silenceTimer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async {
            self.isRecording = false
            self.liveCaption = ""
        }
    }

    // MARK: - Internals

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startStream() throws {
        transcript = ""
        liveCaption = ""
        lastNonEmptyPartial = ""
        lastSpeechTime = Date()

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        startSilenceMonitor()

        recognitionTask = speechRecognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let full = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)

                // Update silence timer (user is talking)
                if !full.isEmpty {
                    self.lastSpeechTime = Date()
                }

                // Track last partial
                if !full.isEmpty {
                    self.lastNonEmptyPartial = full
                }

                // Update UI
                DispatchQueue.main.async {
                    self.transcript = full
                    self.liveCaption = full
                }

                // Real final from Apple
                if result.isFinal {
                    self.emitFinalUtterance(full)
                }
            }

            // Ignore harmless errors
            if let error = error as NSError?,
               error.code != 1101, error.code != 216 {
                DispatchQueue.main.async {
                }
            }
        }
    }

    // MARK: - Finalizing without stopping engine

    private func emitFinalUtterance(_ text: String) {
        let final = text.isEmpty ? lastNonEmptyPartial : text
        guard !final.isEmpty else { return }

        DispatchQueue.main.async {
            print("FINAL UTTERANCE:", final)
            self.onUtterance?(final)
            self.liveCaption = ""
        }

        AudioServicesPlaySystemSound(1003)

        // Prepare for next utterance
        restartRecognitionTask()
    }

    /// Called when silence finalizes the phrase
    private func finalizeFromSilence() {
        let final = lastNonEmptyPartial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else { return }

        if VOICE_DEBUG {
            print("Silence Finalization →", final)
        }

        emitFinalUtterance(final)
    }

    // MARK: - Restart recognizer

    private func restartRecognitionTask() {
        recognitionTask?.finish()
        recognitionTask = nil
        lastNonEmptyPartial = ""

        // Very short delay to avoid conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? self.startStream()
        }
    }

    // MARK: - Silence Monitor

    private func startSilenceMonitor() {
        silenceTimer?.invalidate()

        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }

            let silenceDuration = Date().timeIntervalSince(self.lastSpeechTime)

            if silenceDuration >= self.silenceTimeout {
                self.finalizeFromSilence()
            }
        }
    }

    // MARK: - Interruptions

    private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            stop()
        case .ended:
            break
        @unknown default:
            break
        }
    }
}
