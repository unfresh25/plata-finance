import Foundation
import Speech
import AVFoundation

// Transcripción de voz a texto on-device. Envuelve SFSpeechRecognizer +
// AVAudioEngine.
//
// Concurrencia: los callbacks de Speech y del tap de audio llegan en hilos de
// fondo arbitrarios. Por eso esta clase NO está aislada al MainActor: manejarla
// como @MainActor hacía que esos callbacks (permisos, recognitionTask, tap)
// cruzaran el aislamiento y la app crasheara con _dispatch_assert_queue_fail.
// El estado observable para la UI vive en SpeechCapture (@MainActor); esta clase
// solo publica cambios llamando handlers que ya saltan al MainActor.
//
// Uso: fijar onTranscript/onLevel/onFinish, luego start()/stop().

// nonisolated a nivel de tipo: con SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor todo
// heredaría el MainActor; esta clase debe vivir FUERA de él porque sus callbacks
// (permisos, recognitionTask, tap de audio) llegan en hilos de fondo.
nonisolated final class SpeechRecognizer: @unchecked Sendable {
    // Handlers hacia la UI. Se invocan siempre en el MainActor (ver SpeechCapture).
    var onTranscript: (@Sendable (String) -> Void)?
    var onLevel: (@Sendable (Float) -> Void)?
    var onFinish: (@Sendable () -> Void)?
    var onError: (@Sendable (String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es_CO"))
        ?? SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let lock = NSLock()
    private var recording = false
    // Intención del usuario de estar grabando. Si suelta el botón mientras el
    // motor aún arranca (p. ej. esperando el diálogo de permisos la 1ª vez), esto
    // se pone en false y start() aborta en vez de quedar grabando indefinidamente.
    private var wantsRecording = false

    var isRecording: Bool { lock.withLock { recording } }

    // MARK: - Permisos

    // nonisolated EXPLÍCITO: con SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor, un
    // método async sin marcar hereda el MainActor y la continuation se reanuda
    // esperando ese executor; como el callback de TCC/permits reanuda en una cola
    // de fondo, Swift dispara _dispatch_assert_queue_fail. nonisolated desliga la
    // continuation de cualquier actor.
    nonisolated static func requestSpeechAuth() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    nonisolated static func requestMicAuth() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Captura

    /// Pide permisos por adelantado (idempotente). Llamar al abrir el sheet para
    /// que el primer hold no compita con el diálogo de permisos.
    func prewarmPermissions() async {
        _ = await Self.requestSpeechAuth()
        _ = await Self.requestMicAuth()
    }

    func start() async {
        guard !isRecording else { return }
        lock.withLock { wantsRecording = true }

        guard await Self.requestSpeechAuth() else {
            onError?("Activa el reconocimiento de voz en Ajustes para dictar.")
            return
        }
        guard await Self.requestMicAuth() else {
            onError?("Activa el micrófono en Ajustes para dictar.")
            return
        }
        // El usuario pudo soltar el botón mientras se pedían permisos/arrancaba.
        guard lock.withLock({ wantsRecording }) else {
            onFinish?()
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            onError?("El reconocimiento de voz no está disponible ahora.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError?("No se pudo iniciar el audio.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            onError?("El micrófono no está disponible ahora.")
            deactivateSession()
            self.request = nil
            return
        }

        let levelHandler = onLevel
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            if let levelHandler { levelHandler(Self.rmsLevel(buffer)) }
        }

        // Última comprobación antes de arrancar: si ya soltó, abortar limpio.
        guard lock.withLock({ wantsRecording }) else {
            inputNode.removeTap(onBus: 0)
            cleanup()
            deactivateSession()
            onFinish?()
            return
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            onError?("No se pudo iniciar el micrófono.")
            cleanup()
            deactivateSession()
            return
        }

        lock.withLock { recording = true }

        let transcriptHandler = onTranscript
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                transcriptHandler?(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                self?.stop()
            }
        }
    }

    func stop() {
        // Cancela también una grabación aún en arranque (wantsRecording): así, si
        // el usuario suelta antes de que el motor arranque, start() aborta.
        let wasRecording = lock.withLock { () -> Bool in
            wantsRecording = false
            let w = recording
            recording = false
            return w
        }
        guard wasRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        cleanup()
        deactivateSession()
        onFinish?()
    }

    // MARK: - Interno

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanup() {
        request = nil
        task = nil
    }

    /// RMS del buffer → 0…1. Función pura, segura para el hilo de audio.
    private static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frames { sum += channel[i] * channel[i] }
        let rms = (sum / Float(frames)).squareRoot()
        // Ganancia alta + curva raíz: la voz normal tiene RMS bajo (~0.02–0.1);
        // así el nivel se nota claramente en la animación en vez de quedar plano.
        let boosted = min(1, rms * 14)
        return sqrt(boosted)   // expande la parte baja del rango
    }
}

// Estado observable para la UI. Vive en el MainActor y traduce los callbacks del
// SpeechRecognizer (que llegan en hilos de fondo) a mutaciones en el MainActor.

@Observable
@MainActor
final class SpeechCapture {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var errorMessage: String?
    private(set) var level: Float = 0

    private let recognizer = SpeechRecognizer()

    init() {
        recognizer.onTranscript = { [weak self] text in
            Task { @MainActor in self?.transcript = text }
        }
        recognizer.onLevel = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.level = self.level * 0.7 + value * 0.3
            }
        }
        recognizer.onFinish = { [weak self] in
            Task { @MainActor in
                self?.isRecording = false
                self?.level = 0
            }
        }
        recognizer.onError = { [weak self] message in
            Task { @MainActor in
                self?.errorMessage = message
                self?.isRecording = false
            }
        }
    }

    /// Pide permisos por adelantado al abrir el sheet (evita la carrera con el
    /// diálogo de permisos durante el primer hold, que dejaba el motor colgado).
    func prewarm() {
        Task { await recognizer.prewarmPermissions() }
    }

    func start() {
        errorMessage = nil
        transcript = ""
        isRecording = true
        Task { await recognizer.start() }
        // Si arrancar falló, onError/onFinish revertirán isRecording.
    }

    func stop() {
        recognizer.stop()
    }
}
