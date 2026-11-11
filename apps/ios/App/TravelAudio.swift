import AVFoundation
import Speech
import Observation

@MainActor @Observable final class TravelAudio: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var listening = false
    private(set) var preparing = false
    private(set) var transcript = ""
    var error: String?
    private let engine = AVAudioEngine()
    private let speaker = AVSpeechSynthesizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
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
        guard !listening, !preparing else { return }
        stop(); speaker.stopSpeaking(at: .immediate)
        error = nil; transcript = ""; preparing = true
        let ticket = token
        defer { if token == ticket { preparing = false } }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard token == ticket, !Task.isCancelled else { return }
        guard speech == .authorized, microphone else {
            error = "Allow Microphone and Speech Recognition in iPhone Settings to speak. You can always type instead."
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES")), recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            error = "On-device Spanish recognition isn't available on this phone yet. Check downloaded speech resources, or type your reply. Audio won't be sent to a server."
            return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audio.setActive(true); sessionActive = true
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            request.contextualStrings = ["billete", "andén", "transbordo", "reserva", "café con leche", "la cuenta"]
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioError.unavailable }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
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
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.stop()
            }
        } catch { stop(); self.error = "The microphone couldn't start. Try again or type your reply." }
    }
    func stop() {
        token = UUID(); timeout?.cancel(); timeout = nil
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        listening = false; preparing = false
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
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
            guard let self, !self.listening, !self.speaker.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.sessionActive = false
        }
    }
    isolated deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }
    func silence() { speaker.stopSpeaking(at: .immediate); stop() }
    private enum AudioError: Error { case unavailable }
}
