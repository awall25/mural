import AVFoundation
import Speech
import Observation
import MuralCore

@MainActor @Observable final class TravelAudio: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var listening = false
    private(set) var preparing = false
    private(set) var transcript = ""
    private(set) var finishing = false
    private(set) var preparationMessage = "Preparing Spanish speech…"
    var error: String?
    private let engine = AVAudioEngine()
    private let speaker = AVSpeechSynthesizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var legacyRecognizer: SFSpeechRecognizer?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var installation: AssetInstallationRequest?
    private var speechTranscript = TravelSpeechTranscript()
    private var hasTap = false
    private var sessionActive = false
    private var timeout: Task<Void, Never>?
    private var token = UUID()
    private var interruption: NSObjectProtocol?

    override init() {
        super.init()
        speaker.delegate = self
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop(); self?.speaker.stopSpeaking(at: .immediate) }
        }
    }
    func start() async {
        guard !listening, !preparing, !finishing else { return }
        silence()
        error = nil; transcript = ""; speechTranscript = TravelSpeechTranscript(); preparing = true
        preparationMessage = "Checking Spanish speech…"
        let ticket = token
        defer { if token == ticket { preparing = false } }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard token == ticket, !Task.isCancelled else { return }
        guard microphone else {
            error = "Allow Microphone access in iPhone Settings to speak. You can always type instead."
            return
        }
        do {
            if SpeechTranscriber.isAvailable,
               let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "es-ES")) {
                guard token == ticket else { return }
                try await startAnalyzer(locale: locale, ticket: ticket)
            } else {
                guard token == ticket else { return }
                try await startLegacy(ticket: ticket)
            }
            guard token == ticket, listening else { return }
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.finishRecording()
            }
        } catch is CancellationError { if token == ticket { stop() } }
        catch {
            guard token == ticket else { return }
            let message = preparationMessage
            stop()
            if let setup = error as? SpeechSetupError { self.error = setup.localizedDescription }
            else if message == "Downloading Spanish speech…" {
                self.error = "The Spanish speech download couldn't finish. Connect to Wi-Fi, check free storage, and tap to try again. Your API key isn't involved in this download."
            } else {
                self.error = "Spanish speech couldn't start. Try again after the phone finishes downloading speech resources, or type your reply. Audio stays on this phone."
            }
        }
    }
    private func startAnalyzer(locale: Locale, ticket: UUID) async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        // AssetInventory installs the actual recognizer model, not a text-to-speech voice.
        // It handles locale reservation and reuses models already installed by the system.
        if let download = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            guard token == ticket else { return }
            installation = download; preparationMessage = "Downloading Spanish speech…"
            try await download.downloadAndInstall()
            guard token == ticket else { return }
            installation = nil
        }
        guard token == ticket else { return }
        preparationMessage = "Starting Spanish speech…"
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audio.setActive(true); sessionActive = true
        let natural = engine.inputNode.outputFormat(forBus: 0)
        guard natural.sampleRate > 0, natural.channelCount > 0,
              let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: natural) else {
            throw SpeechSetupError.microphone
        }
        guard token == ticket else { return }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: format)
        guard token == ticket else { await analyzer.cancelAndFinishNow(); return }
        let stream = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = stream.continuation
        let bridge = try TravelSpeechInput(format: format, naturalFormat: natural, continuation: stream.continuation) { [weak self] in
            Task { @MainActor in
                guard let self, self.token == ticket else { return }
                self.stop(); self.error = "The microphone format couldn't be converted for Spanish speech. Please try again."
            }
        }
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self, self.token == ticket, !Task.isCancelled else { return }
                    self.speechTranscript.receive(String(result.text.characters), isFinal: result.isFinal)
                    self.transcript = self.speechTranscript.text
                }
            } catch {
                guard let self, self.token == ticket, !Task.isCancelled else { return }
                self.stop(); self.error = "Spanish recognition stopped. Your transcript is still editable; try recording again if needed."
            }
        }
        try await analyzer.start(inputSequence: stream.stream)
        guard token == ticket else { await analyzer.cancelAndFinishNow(); return }
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: natural) { buffer, _ in bridge.receive(buffer) }
        hasTap = true
        engine.prepare(); try engine.start(); listening = true
    }
    private func startLegacy(ticket: UUID) async throws {
        preparationMessage = "Checking installed Spanish dictation…"
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard token == ticket else { return }
        guard authorization == .authorized else { throw SpeechSetupError.permission }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES")), recognizer.supportsOnDeviceRecognition else {
            throw SpeechSetupError.unsupported
        }
        // isAvailable reflects the older service's availability; never use it as a
        // hardware/model-installation test. The request itself enforces local recognition.
        legacyRecognizer = recognizer
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audio.setActive(true); sessionActive = true
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
        request.contextualStrings = ["billete", "andén", "transbordo", "reserva", "café con leche", "la cuenta"]
        self.request = request
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechSetupError.microphone }
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        hasTap = true
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, failure in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true
            let failed = failure != nil
            Task { @MainActor in
                guard let self, self.token == ticket else { return }
                if let text { self.transcript = text }
                if final || failed {
                    self.stop()
                    if failed && self.transcript.isEmpty { self.error = "Couldn't hear a Spanish reply. Please try again or type it." }
                }
            }
        }
        engine.prepare(); try engine.start(); listening = true
    }
    /// Finish the input, then let the recognizer deliver the last words before editing/sending.
    func finishRecording() {
        guard listening, !finishing else { return }
        stopMicrophone(); timeout?.cancel(); timeout = nil
        listening = false; finishing = true; preparationMessage = "Finishing your transcript…"
        let ticket = token
        inputContinuation?.finish(); inputContinuation = nil
        if let analyzer {
            finishTask = Task { [weak self] in
                do {
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    if let results = self?.resultsTask { await results.value }
                } catch { /* Keep the partial transcript available for review. */ }
                guard let self, self.token == ticket else { return }
                self.stop()
                if self.transcript.isEmpty { self.error = "No Spanish speech was detected. Tap to try again or type your reply." }
            }
        } else {
            request?.endAudio(); recognition?.finish()
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard let self, self.token == ticket else { return }
            self.stop()
            if self.transcript.isEmpty { self.error = "No Spanish speech was detected. Tap to try again or type your reply." }
        }
    }
    private func stopMicrophone() {
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }
    func stop() {
        token = UUID(); timeout?.cancel(); timeout = nil
        finishTask?.cancel(); finishTask = nil
        installation?.progress.cancel(); installation = nil
        stopMicrophone()
        inputContinuation?.finish(); inputContinuation = nil
        resultsTask?.cancel(); resultsTask = nil
        if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
        analyzer = nil
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil; legacyRecognizer = nil
        listening = false; preparing = false; finishing = false
    }
    func speak(_ text: String, slow: Bool = false) {
        stop(); speaker.stopSpeaking(at: .immediate)
        guard let voice = AVSpeechSynthesisVoice(language: "es-ES") else { error = "A Spanish voice isn't installed. The written phrase is still available."; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true); sessionActive = true
            let utterance = AVSpeechUtterance(string: text); utterance.voice = voice
            utterance.rate = slow ? 0.36 : AVSpeechUtteranceDefaultSpeechRate
            speaker.speak(utterance)
        } catch { self.error = "Audio playback isn't available right now." }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, !self.listening, !self.preparing, !self.finishing, !self.speaker.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.sessionActive = false
        }
    }
    isolated deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }
    func silence() { speaker.stopSpeaking(at: .immediate); stop() }
    private enum SpeechSetupError: LocalizedError {
        case unsupported, permission, microphone
        var errorDescription: String? {
            switch self {
            case .unsupported: "This phone doesn't currently offer an on-device Spanish recognizer. You can type your reply; no microphone audio will be uploaded."
            case .permission: "Allow Speech Recognition in iPhone Settings for installed dictation, or type your reply."
            case .microphone: "The microphone format isn't available. Disconnect other audio devices and try again."
            }
        }
    }
}


/// The engine invokes its tap serially. Convert/copy into owned buffers before the
/// tap returns, so SpeechAnalyzer never reads reused microphone memory.
private final class TravelSpeechInput: @unchecked Sendable {
    private let format: AVAudioFormat
    private let converter: AVAudioConverter
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let onFailure: @Sendable () -> Void
    init(format: AVAudioFormat, naturalFormat: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation, onFailure: @escaping @Sendable () -> Void) throws {
        self.format = format; self.continuation = continuation; self.onFailure = onFailure
        guard let converter = AVAudioConverter(from: naturalFormat, to: format) else { throw ConversionError.unavailable }
        self.converter = converter
    }
    func receive(_ buffer: AVAudioPCMBuffer) {
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { onFailure(); return }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            guard !supplied else { state.pointee = .noDataNow; return nil }
            supplied = true; state.pointee = .haveData; return buffer
        }
        guard status != .error, error == nil else { onFailure(); return }
        if output.frameLength > 0 { continuation.yield(AnalyzerInput(buffer: output)) }
    }
    private enum ConversionError: Error { case unavailable }
}
