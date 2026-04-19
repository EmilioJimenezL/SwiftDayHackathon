import SwiftUI
import AVFoundation

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @State private var editableText: String = ""
    @State private var isEditing = false
    @State private var isSpeaking = false
    @State private var speechUtterances: [AVSpeechUtterance] = []
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    var capture: Capture? { appState.currentCapture }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: CFSpacing.cardGap) {
                    // Extracted Text card
                    extractedTextCard
                    
                    // Formula cards
                    if let formulas = capture?.detectedFormulas, !formulas.isEmpty {
                        ForEach(formulas) { formula in
                            FormulaCard(formula: formula)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(CFSpacing.base)
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationTitle("Resultados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { appState.showResults = false }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(Color.cfPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Color.cfPrimary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    CFPrimaryButton("Obtener ayuda con el contenido →") {
                        appState.requestHelp()
                    }
                    .padding(CFSpacing.base)
                }
                .background(Color.cfSurface)
            }
            .sheet(isPresented: $appState.showHelpSheet) {
                HelpSelectionSheet()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            editableText = capture?.extractedText ?? ""
            if speechSynthesizer.isSpeaking {
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
            isSpeaking = false
        }
    }
    
    private func buildNarrationText() -> String {
        var parts: [String] = []
        let title = capture?.title ?? "Resultados"
        parts.append("Título: \(title)")
        let text = editableText.isEmpty ? (capture?.extractedText ?? "") : editableText
        if !text.isEmpty {
            parts.append("Texto extraído: \(text)")
        }
        if let formulas = capture?.detectedFormulas, !formulas.isEmpty {
            for (index, formula) in formulas.enumerated() {
                parts.append("Fórmula \(index + 1): \(formula.rawText)")
                if !formula.steps.isEmpty {
                    parts.append("Pasos de la solución:")
                    for step in formula.steps.sorted(by: { $0.number < $1.number }) {
                        let desc = step.description
                        let expr = step.expression
                        if expr.isEmpty {
                            parts.append("Paso \(step.number): \(desc)")
                        } else {
                            parts.append("Paso \(step.number): \(desc). Expresión: \(expr)")
                        }
                    }
                }
            }
        }
        return parts.joined(separator: ". ")
    }

    private func toggleSpeech() {
        if isSpeaking {
            // Stop current speech
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            #if DEBUG
            print("Speech synthesizer stopped")
            #endif
            return
        }
        let narration = buildNarrationText()
        guard !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: narration)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.2
        self.speechUtterances = [utterance]
        speechSynthesizer.speak(utterance)
        isSpeaking = true
        #if DEBUG
        print("Speech synthesizer started...")
        #endif
    }
    
    private var extractedTextCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.sm) {
            HStack {
                Text("Texto extraído")
                    .font(CFFont.heading1())
                    .foregroundColor(Color.cfText1)
                Spacer()
                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                        .font(.system(size: 20))
                        .foregroundColor(Color.cfAccent)
                }
                .accessibilityLabel(isEditing ? "Guardar edición" : "Editar texto")
            }
            
            if isEditing {
                TextEditor(text: $editableText)
                    .font(CFFont.body())
                    .foregroundColor(Color.cfText2)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.cfBackground)
                    .cornerRadius(8)
            } else {
                Text(editableText.isEmpty ? (capture?.extractedText ?? "") : editableText)
                    .font(CFFont.body())
                    .foregroundColor(Color.cfText2)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
                .padding(.top, 4)
            
            HStack(spacing: CFSpacing.base) {
                Button(action: {
                    UIPasteboard.general.string = editableText
                }) {
                    Label("Copiar", systemImage: "doc.on.doc")
                        .font(CFFont.body(14, weight: .medium))
                        .foregroundColor(Color.cfText2)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(action: { toggleSpeech() }) {
                    Label(isSpeaking ? "Pausar lectura" : "Leer en voz alta", systemImage: isSpeaking ? "pause.circle" : "speaker.wave.2")
                        .font(CFFont.body(14, weight: .medium))
                        .foregroundColor(Color.cfText2)
                }
                .accessibilityLabel(isSpeaking ? "Pausar lectura" : "Leer en voz alta")
                
                Spacer()
            }
        }
        .padding(CFSpacing.base)
        .background(Color.cfSurface)
        .cornerRadius(CFSpacing.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Formula Card
struct FormulaCard: View {
    let formula: MathFormula
    @State private var showSteps = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.sm) {
            HStack {
                Text("Fórmula detectada")
                    .font(CFFont.heading1())
                    .foregroundColor(Color.cfText1)
                Spacer()
                Text("Σ")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.cfAccent)
            }
            
            // Formula display
            Text(formula.rawText)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(Color.cfText1)
                .padding(CFSpacing.base)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cfBackground)
                .cornerRadius(10)
            
            if showSteps {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(formula.steps) { step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(step.number).")
                                .font(CFFont.body(14, weight: .semibold))
                                .foregroundColor(Color.cfAccent)
                                .frame(width: 20, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.description)
                                    .font(CFFont.body(14))
                                    .foregroundColor(Color.cfText2)
                                Text(step.expression)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.cfPrimary)
                            }
                        }
                    }
                }
                .padding(CFSpacing.base)
                .background(Color.cfBackground)
                .cornerRadius(10)
            }
            
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(CFAnimation.spring) {
                        showSteps.toggle()
                    }
                }) {
                    Label(showSteps ? "Ocultar pasos" : "Resolver", systemImage: showSteps ? "chevron.up" : "equal.square.fill")
                        .font(CFFont.body(14, weight: .semibold))
                        .foregroundColor(Color.cfAccent)
                        .padding(.horizontal, CFSpacing.base)
                        .padding(.vertical, 8)
                        .background(Color.cfAccent.opacity(0.1))
                        .cornerRadius(CFSpacing.pillRadius)
                }
            }
        }
        .padding(CFSpacing.base)
        .background(Color.cfSurface)
        .cornerRadius(CFSpacing.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ResultsView()
        .environmentObject({ let s = AppState(); s.currentCapture = Capture.mockData[0]; return s }())
}
