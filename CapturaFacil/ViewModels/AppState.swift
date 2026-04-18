import SwiftUI

@MainActor
class AppState: ObservableObject {

    @Published var captures:           [Capture]       = Capture.mockData
    @Published var currentCapture:     Capture?        = nil
    @Published var selectedHelpOption: HelpOption?     = nil
    @Published var processingState:    ProcessingState = .idle
    @Published var selectedTab:        Int             = 0
    @Published var showCamera:         Bool            = false
    @Published var showProcessing:     Bool            = false
    @Published var showResults:        Bool            = false
    @Published var showHelpSheet:      Bool            = false
    @Published var showExplanation:    Bool            = false
    @Published var errorMessage:       String?         = nil
    @Published var showError:          Bool            = false

    private let captureService: CaptureServiceProtocol

    init(captureService: CaptureServiceProtocol = CaptureService()) {
        self.captureService = captureService
    }

    func startCapture()  { showCamera = true  }
    func cancelCapture() { showCamera = false }

    func didCaptureImage(_ image: UIImage) {
        showCamera      = false
        showProcessing  = true
        processingState = .processing(message: "Extrayendo texto y fórmulas...")
        Task { await runPipeline(image: image) }
    }

    private func runPipeline(image: UIImage) async {
        do {
            let messages = [
                "Extrayendo texto y fórmulas...",
                "Analizando el contenido...",
                "Detectando fórmulas matemáticas...",
                "Generando explicación accesible..."
            ]
            let messageTask = Task {
                for (i, msg) in messages.dropFirst().enumerated() {
                    try await Task.sleep(for: .seconds(0.9 * Double(i + 1)))
                    processingState = .processing(message: msg)
                }
            }

            let capture = try await captureService.process(image: image)
            messageTask.cancel()

            currentCapture  = capture
            processingState = .results
            showProcessing  = false
            showResults     = true

        } catch {
            showProcessing  = false
            showError       = true
            errorMessage    = error.localizedDescription
            processingState = .error(error.localizedDescription)
        }
    }

    func requestHelp() { showHelpSheet = true }

    func selectHelp(_ option: HelpOption) {
        selectedHelpOption = option
        showHelpSheet      = false
        showExplanation    = true
    }

    func saveToHistory() {
        if let capture = currentCapture,
           !captures.contains(where: { $0.id == capture.id }) {
            captures.insert(capture, at: 0)
        }
        dismissAll()
    }

    func dismissAll() {
        showResults        = false
        showExplanation    = false
        showHelpSheet      = false
        currentCapture     = nil
        selectedHelpOption = nil
        selectedTab        = 0
        processingState    = .idle
    }

    func dismissError() {
        showError       = false
        errorMessage    = nil
        processingState = .idle
    }
}
