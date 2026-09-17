import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - Generador de QR

/// Genera una imagen de código QR a partir de un string (el código de invitación
/// del hogar). Usa CoreImage — sin dependencias ni permisos. El QR se dibuja en
/// el color de tinta actual (template) para adaptarse a claro/oscuro.
enum QRCodeGenerator {
    private static let context = CIContext()

    static func image(from string: String) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Escala para que se vea nítido (el QR nativo es minúsculo).
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(decorative: cg, scale: 1)
    }
}

/// Vista de QR lista para usar: fondo claro con el patrón oscuro (un QR necesita
/// contraste alto y fondo claro para escanear bien, incluso en modo oscuro).
struct QRCodeView: View {
    let code: String
    var size: CGFloat = 200

    var body: some View {
        Group {
            if let img = QRCodeGenerator.image(from: code) {
                img
                    .interpolation(.none)   // bordes nítidos, no borrosos
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
        // Siempre sobre blanco: garantiza que sea escaneable en ambos temas.
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.stroke.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Escáner de QR (cámara)

/// Escáner de códigos QR con AVFoundation. Llama a `onScan` con el texto la
/// primera vez que detecta un QR válido. Requiere NSCameraUsageDescription.
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let c = QRScannerController()
        c.onScan = onScan
        return c
    }
    func updateUIViewController(_ controller: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configure()
    }

    private func configure() {
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)

        // Arrancar la sesión fuera del main thread (startRunning bloquea).
        // nonisolated(unsafe) porque AVCaptureSession no es Sendable pero su uso
        // aquí está serializado (solo se arranca una vez desde este controlador).
        nonisolated(unsafe) let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didScan,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        didScan = true
        AVCaptureDevice.default(for: .video).map { _ in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        onScan?(value)
    }
}
