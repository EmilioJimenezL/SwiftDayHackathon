import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject var appState: AppState
    
    private var message: String {
        if case .processing(let msg) = appState.processingState {
            return msg
        }
        return "Procesando..."
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.cfBackground, Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            CFLoadingIndicator(message: message)
        }
        .transition(.opacity)
    }
}

#Preview {
    ProcessingView()
        .environmentObject(AppState())
}
