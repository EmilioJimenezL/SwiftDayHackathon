import SwiftUI

// MARK: - S-05 Help Selection Sheet
struct HelpSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var textOptions: [HelpOption] { HelpOption.allCases.filter { $0.category == .text } }
    var mathOptions: [HelpOption] { HelpOption.allCases.filter { $0.category == .math } }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: CFSpacing.xl) {
                    // Header
                    VStack(spacing: 8) {
                        Text("¿Cómo puedo ayudar?")
                            .font(CFFont.display(28))
                            .foregroundColor(Color.cfText1)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("Elige una opción para procesar el contenido capturado.")
                            .font(CFFont.body())
                            .foregroundColor(Color.cfText2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, CFSpacing.sm)
                    
                    // Text Help section
                    VStack(alignment: .leading, spacing: CFSpacing.cardGap) {
                        Text(HelpCategory.text.label)
                            .font(CFFont.heading2())
                            .foregroundColor(Color.cfText1)
                        
                        Divider()
                        
                        ForEach(textOptions) { option in
                            HelpOptionRow(option: option) {
                                appState.selectHelp(option)
                            }
                        }
                    }
                    
                    // Math Help section
                    VStack(alignment: .leading, spacing: CFSpacing.cardGap) {
                        Text(HelpCategory.math.label)
                            .font(CFFont.heading2())
                            .foregroundColor(Color.cfText1)
                        
                        Divider()
                        
                        ForEach(mathOptions) { option in
                            HelpOptionRow(option: option) {
                                appState.selectHelp(option)
                            }
                        }
                    }
                    
                    // Cancel
                    CFSecondaryButton("Cancelar") {
                        dismiss()
                    }
                    .padding(.top, CFSpacing.sm)
                    
                    Spacer(minLength: CFSpacing.xl)
                }
                .padding(CFSpacing.base)
            }
            .background(Color.cfSurface.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - S-06 Explanation View
struct ExplanationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    
    var capture: Capture? { appState.currentCapture }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: CFSpacing.cardGap) {
                    if let blocks = capture?.explanations, !blocks.isEmpty {
                        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                            ExplanationBlockView(block: block, delay: Double(index) * CFAnimation.stagger)
                        }
                        
                        // Leaf illustration placeholder
                        RoundedRectangle(cornerRadius: CFSpacing.cardRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.6), Color.green.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                            .padding(.top, CFSpacing.sm)
                    } else {
                        ProgressView()
                            .padding(.top, 60)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(CFSpacing.base)
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationTitle("Tu explicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
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
                VStack(spacing: CFSpacing.sm) {
                    Divider()
                    CFSecondaryButton("Editar", icon: "pencil") {
                        showEdit = true
                    }
                    CFPrimaryButton("Guardar en historial", icon: "bookmark.fill") {
                        appState.saveToHistory()
                        dismiss()
                    }
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "house")
                                .font(.system(size: 13))
                            Text("Volver al inicio")
                                .font(CFFont.body(14))
                        }
                        .foregroundColor(Color.cfAccent)
                        .frame(height: 36)
                    }
                    .accessibilityLabel("Volver al inicio")
                }
                .padding(.horizontal, CFSpacing.base)
                .padding(.bottom, 8)
                .background(Color.cfSurface)
            }
        }
    }
}

#Preview {
    HelpSelectionSheet()
        .environmentObject(AppState())
}
