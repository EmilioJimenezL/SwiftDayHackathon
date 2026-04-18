import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var captures: [Capture] = Capture.mockData
    @Published var processingState: ProcessingState = .idle
    @Published var currentCapture: Capture? = nil
    @Published var selectedHelpOption: HelpOption? = nil
    
    // Navigation
    @Published var selectedTab: Int = 0
    @Published var showCamera: Bool = false
    @Published var showProcessing: Bool = false
    @Published var showResults: Bool = false
    @Published var showHelpSheet: Bool = false
    @Published var showExplanation: Bool = false
    
    // Processing messages cycle
    private let processingMessages = [
        "Extrayendo texto y fórmulas...",
        "Analizando el contenido...",
        "Detectando fórmulas matemáticas...",
        "Casi listo..."
    ]
    
    func startCapture() {
        showCamera = true
    }
    
    func didCaptureImage() {
        showCamera = false
        showProcessing = true
        simulateProcessing()
    }
    
    func cancelCapture() {
        showCamera = false
    }
    
    private func simulateProcessing() {
        var messageIndex = 0
        processingState = .processing(message: processingMessages[0])
        
        // Cycle through messages
        Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            messageIndex += 1
            if messageIndex < self.processingMessages.count {
                Task { @MainActor in
                    self.processingState = .processing(message: self.processingMessages[messageIndex])
                }
            } else {
                timer.invalidate()
                Task { @MainActor in
                    self.finishProcessing()
                }
            }
        }
    }
    
    private func finishProcessing() {
        currentCapture = Capture.mockData[0]
        showProcessing = false
        showResults = true
    }
    
    func requestHelp() {
        showHelpSheet = true
    }
    
    func selectHelp(_ option: HelpOption) {
        selectedHelpOption = option
        showHelpSheet = false
        showExplanation = true
    }
    
    func saveToHistory() {
        if let capture = currentCapture {
            if !captures.contains(where: { $0.id == capture.id }) {
                captures.insert(capture, at: 0)
            }
        }
        dismissAll()
    }
    
    func dismissAll() {
        showResults = false
        showExplanation = false
        showHelpSheet = false
        currentCapture = nil
        selectedHelpOption = nil
        selectedTab = 0
    }
}
