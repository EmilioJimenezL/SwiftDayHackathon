import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var greetingVisible = false
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Buenos días."
        case 12..<18: return "Buenas tardes."
        default: return "Buenas noches."
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: CFSpacing.xl) {
                    // Greeting
                    Text(greeting)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.cfText1)
                        .opacity(greetingVisible ? 1 : 0)
                        .offset(y: greetingVisible ? 0 : -8)
                    
                    // Capture CTA card
                    Button(action: { appState.startCapture() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.cfPrimary)
                            
                            VStack(spacing: CFSpacing.sm) {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                    )
                                
                                Text("Capturar con Cámara")
                                    .font(CFFont.heading1())
                                    .foregroundColor(.white)
                                
                                Text("Analiza texto y objetos al instante.")
                                    .font(CFFont.body())
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.vertical, CFSpacing.xl)
                        }
                    }
                    .frame(height: 190)
                    .shadow(color: Color.cfPrimary.opacity(0.4), radius: 16, x: 0, y: 8)
                    .accessibilityLabel("Capturar con cámara. Analiza texto y objetos al instante.")
                    
                    // Recent Captures
                    VStack(spacing: CFSpacing.cardGap) {
                        SectionHeader("Capturas Recientes", actionTitle: "Ver todo") {
                            appState.selectedTab = 1
                        }
                        
                        if appState.captures.isEmpty {
                            Text("No hay capturas recientes.")
                                .font(CFFont.body())
                                .foregroundColor(Color.cfText3)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, CFSpacing.lg)
                        } else {
                            ForEach(appState.captures.prefix(2)) { capture in
                                CaptureCard(capture: capture)
                            }
                        }
                    }
                    
                    // Support Tools
                    VStack(spacing: CFSpacing.cardGap) {
                        SectionHeader("Herramientas de apoyo")
                        
                        HStack(spacing: CFSpacing.cardGap) {
                            SupportToolButton(icon: "speaker.wave.2.fill", title: "Leer en voz alta") { }
                            SupportToolButton(icon: "character.bubble", title: "Traducir") { }
                        }
                        
                        SupportToolButton(icon: "lightbulb.fill", title: "Resumir — Obtén los puntos clave al instante") { }
                            .frame(maxWidth: .infinity)
                    }
                    
                    Spacer(minLength: CFSpacing.xl)
                }
                .padding(.horizontal, CFSpacing.base)
                .padding(.top, CFSpacing.lg)
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(CFAnimation.spring) {
                    greetingVisible = true
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
