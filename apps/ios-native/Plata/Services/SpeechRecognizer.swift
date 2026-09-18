import Foundation
import Speech
import AVFoundation

// Transcripción de voz a texto on-device. Envuelve SFSpeechRecognizer +
// AVAudioEngine y expone un texto observable que la UI muestra en vivo mientras
// el usuario habla. La interpretación a campos del movimiento la hace el backend
// (Gemini); esto solo entrega el texto plano.
//
// Uso: `start()` al mantener pulsado el micrófono, `stop()` al soltar. `transcript`
// se actualiza en vivo. Pide permisos la primera vez.

@Observable
@MainActor
final class SpeechRecognizer {
    /// Texto transcrito hasta el momento (parcial mientras se habla, final al parar).
    private(set) var transcript = ""
    /// Está capturando audio ahora mismo.
    private(set) var isRecording = false
    /// Mensaje de error legible (permiso denegado, no disponible, etc.).
    private(set) var errorMessage: String?
    /// Nivel de audio 0…1 para animar las ondas (RMS suavizado).
    private(set) var level: Float = 0

    // es-CO con respaldo al locale del dispositivo si no está disponible.
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es_CO"))
        ?? SFSpeechRecognizer()

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    // MARK: - Permisos

    /// Pide autorización de reconocimiento de voz y micrófono. Devuelve true si
    /// ambos quedaron concedidos.
    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else {
            errorMessage = "Activa el reconocimiento de voz en Ajustes para dictar."
            return false
        }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        if !micOK {
            errorMessage = "Activa el micrófono en Ajustes para dictar."
        }
        return micOK
    }

    // MARK: - Captura

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""

        guard await requestAuthorization() else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "El reconocimiento de voz no está disponible ahora."
            return
        }

        do {
            try configureSession()
        } catch {
            errorMessage = "No se pudo iniciar el audio."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Preferir on-device cuando el dispositivo lo soporta (privacidad + offline).
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            self?.updateLevel(from: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "No se pudo iniciar el micrófono."
            cleanup()
            return
        }

        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        level = 0
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        cleanup()
        deactivateSession()
    }

    // MARK: - Interno

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanup() {
        request = nil
        task = nil
    }

    /// RMS del buffer → nivel suavizado 0…1 para las ondas.
    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var sum: Float = 0
        for i in 0..<frames { sum += channel[i] * channel[i] }
        let rms = (sum / Float(frames)).squareRoot()
        // Escala perceptual: rms típico de voz ~0.02–0.2.
        let scaled = min(1, max(0, rms * 6))
        Task { @MainActor in
            // Suavizado para que las ondas no tiemblen.
            self.level = self.level * 0.7 + scaled * 0.3
        }
    }
}
