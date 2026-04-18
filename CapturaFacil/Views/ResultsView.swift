import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @State private var editableText: String = ""
    @State private var isEditing = false
    
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
        }
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
                
                Button(action: { }) {
                    Label("Leer en voz alta", systemImage: "speaker.wave.2")
                        .font(CFFont.body(14, weight: .medium))
                        .foregroundColor(Color.cfText2)
                }
                
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
