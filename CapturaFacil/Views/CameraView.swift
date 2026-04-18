import SwiftUI

struct CameraView: View {
    @EnvironmentObject var appState: AppState
    @State private var flashVisible = false
    @State private var showGuide = true
    
    var body: some View {
        ZStack {
            // Camera background simulation
            Color.black.ignoresSafeArea()
            
            // Simulated camera content (pizarrón)
            Image(systemName: "rectangle.on.rectangle")
                .resizable()
                .scaledToFill()
                .foregroundColor(.gray.opacity(0.3))
                .ignoresSafeArea()
            
            // Overlay guide frame
            VStack {
                // Top instruction bar
                HStack {
                    Button(action: { appState.cancelCapture() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Cancelar")
                    
                    Spacer()
                    
                    Text("Alinea con el pizarrón")
                        .font(CFFont.body(15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, CFSpacing.base)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(CFSpacing.pillRadius)
                    
                    Spacer()
                    
                    Button(action: { }) {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Flash")
                }
                .padding(.horizontal, CFSpacing.base)
                .padding(.top, 16)
                
                Spacer()
                
                // Guide rectangle
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.45)
                    .padding(.horizontal, 24)
                    .overlay(
                        // Corner accents
                        GeometryReader { geo in
                            let w = geo.size.width
                            let h = geo.size.height
                            let cornerLen: CGFloat = 24
                            ZStack {
                                // Top-left
                                Path { p in
                                    p.move(to: CGPoint(x: 0, y: cornerLen))
                                    p.addLine(to: .zero)
                                    p.addLine(to: CGPoint(x: cornerLen, y: 0))
                                }
                                .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                
                                // Top-right
                                Path { p in
                                    p.move(to: CGPoint(x: w - cornerLen, y: 0))
                                    p.addLine(to: CGPoint(x: w, y: 0))
                                    p.addLine(to: CGPoint(x: w, y: cornerLen))
                                }
                                .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                
                                // Bottom-left
                                Path { p in
                                    p.move(to: CGPoint(x: 0, y: h - cornerLen))
                                    p.addLine(to: CGPoint(x: 0, y: h))
                                    p.addLine(to: CGPoint(x: cornerLen, y: h))
                                }
                                .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                
                                // Bottom-right
                                Path { p in
                                    p.move(to: CGPoint(x: w - cornerLen, y: h))
                                    p.addLine(to: CGPoint(x: w, y: h))
                                    p.addLine(to: CGPoint(x: w, y: h - cornerLen))
                                }
                                .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            }
                        }
                        .padding(.horizontal, 24)
                    )
                
                Spacer()
                
                // Bottom controls
                HStack(alignment: .center) {
                    // Thumbnail last capture
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    // Shutter button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .accessibilityLabel("Capturar foto")
                    
                    Spacer()
                    
                    // Grid toggle
                    Button(action: { showGuide.toggle() }) {
                        Image(systemName: "grid")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    .accessibilityLabel("Cuadrícula")
                }
                .padding(.horizontal, CFSpacing.xl)
                .padding(.bottom, 40)
            }
            
            // Flash overlay
            Color.white
                .ignoresSafeArea()
                .opacity(flashVisible ? 0.8 : 0)
        }
        .statusBarHidden(true)
    }
    
    private func capturePhoto() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Flash animation
        withAnimation(.easeOut(duration: 0.1)) {
            flashVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.15)) {
                flashVisible = false
            }
            appState.didCaptureImage()
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(AppState())
}
