import Foundation
import Speech
import AVFoundation

// Transcripción de voz a texto on-device. Envuelve SFSpeechRecognizer +
// AVAudioEngine y expone un texto observable que la UI muestra en vivo mientras
// el usuario habla. La interpretación a campos del movimiento la hace el backend
// (Gemini); esto solo entrega el texto plano.
//
// Concurrencia: el tap de audio corre en un hilo de audio en tiempo real, NO en
// el main actor. Por eso el buffer se procesa en una función `nonisolated` y solo
// el resultado (nivel suavizado) se reenvía al main actor. Tocar estado
// @MainActor directamente desde el hilo de audio crashea la app.
//
// Uso: `start()` al mantener pulsado el micrófono, `stop()` al soltar.

@Observable
@MainActor
final class SpeechRecognizer {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var errorMessage: String?
    private(set) var level: Float = 0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es_CO"))
        ?? SFSpeechRecognizer()

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    // MARK: - Permisos

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

        // Sesión de audio.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "No se pudo iniciar el audio."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        // El formato DEBE venir del hardware del input node; usar uno inventado
        // crashea installTap. Si el sample rate es 0 (hardware no listo), abortar.
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "El micrófono no está disponible ahora."
            deactivateSession()
            self.request = nil
            return
        }

        // Callback en un handler nonisolated que salta al main actor. El closure
        // corre en el hilo de audio; NO debe tocar estado @MainActor directamente.
        let onLevel = self.onLevel
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            let value = Self.rmsLevel(buffer)
            onLevel(value)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = "No se pudo iniciar el micrófono."
            cleanup()
            deactivateSession()
            return
        }

        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Este callback puede llegar en un hilo de fondo → saltar al main actor.
            Task { @MainActor [weak self] in
                guard let self else { return }
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
        task?.cancel()
        cleanup()
        deactivateSession()
    }

    // MARK: - Interno

    /// Handler seguro para el hilo de audio: recibe el nivel ya calculado y lo
    /// entrega al main actor con suavizado. `nonisolated` a propósito.
    private nonisolated var onLevel: @Sendable (Float) -> Void {
        { value in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.level = self.level * 0.7 + value * 0.3
            }
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanup() {
        request = nil
        task = nil
    }

    /// RMS del buffer → 0…1. Función pura, segura para el hilo de audio.
    private nonisolated static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frames { sum += channel[i] * channel[i] }
        let rms = (sum / Float(frames)).squareRoot()
        return min(1, max(0, rms * 6))
    }
}
