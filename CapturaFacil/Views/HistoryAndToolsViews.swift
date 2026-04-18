import SwiftUI

// MARK: - History View
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    
    var filtered: [Capture] {
        if searchText.isEmpty { return appState.captures }
        return appState.captures.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.extractedText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if appState.captures.isEmpty {
                    VStack(spacing: CFSpacing.base) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 52))
                            .foregroundColor(Color.cfBorder)
                        Text("Sin capturas")
                            .font(CFFont.heading1())
                            .foregroundColor(Color.cfText2)
                        Text("Las capturas procesadas aparecerán aquí.")
                            .font(CFFont.body())
                            .foregroundColor(Color.cfText3)
                            .multilineTextAlignment(.center)
                        CFPrimaryButton("Nueva captura") {
                            appState.startCapture()
                        }
                        .frame(maxWidth: 240)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cfBackground)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: CFSpacing.cardGap) {
                            ForEach(filtered) { capture in
                                CaptureCard(capture: capture)
                                    .padding(.horizontal, CFSpacing.base)
                            }
                        }
                        .padding(.top, CFSpacing.sm)
                        .padding(.bottom, CFSpacing.xl)
                    }
                    .searchable(text: $searchText, prompt: "Buscar capturas...")
                    .background(Color.cfBackground)
                }
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { appState.startCapture() }) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(Color.cfPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Tools View
struct ToolsView: View {
    @EnvironmentObject var appState: AppState
    
    let tools: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("speaker.wave.2.fill", "Leer en voz alta", "Escucha cualquier texto capturado.", Color(hex: "#4A90C4")),
        ("character.bubble.fill", "Traducir", "Traduce contenido al idioma que necesitas.", Color(hex: "#5BAD8F")),
        ("lightbulb.fill", "Resumir", "Obtén los puntos clave de inmediato.", Color(hex: "#E0924A")),
        ("function", "Resolver fórmulas", "Desglose matemático paso a paso.", Color(hex: "#9B6FD8")),
        ("text.magnifyingglass", "OCR avanzado", "Reconocimiento de texto manuscrito.", Color(hex: "#D85A5A")),
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: CFSpacing.cardGap) {
                    ForEach(tools, id: \.title) { tool in
                        toolRow(tool)
                    }
                }
                .padding(CFSpacing.base)
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationTitle("Herramientas")
        }
    }
    
    private func toolRow(_ tool: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        Button(action: { }) {
            HStack(spacing: CFSpacing.base) {
                Circle()
                    .fill(tool.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: tool.icon)
                            .font(.system(size: 22))
                            .foregroundColor(tool.color)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.title)
                        .font(CFFont.heading2())
                        .foregroundColor(Color.cfText1)
                    Text(tool.subtitle)
                        .font(CFFont.body(14))
                        .foregroundColor(Color.cfText2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.cfText3)
            }
            .padding(CFSpacing.base)
            .background(Color.cfSurface)
            .cornerRadius(CFSpacing.cardRadius)
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .accessibilityLabel("\(tool.title): \(tool.subtitle)")
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
