import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Inicio", systemImage: "house.fill")
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    Label("Historial", systemImage: "clock")
                }
                .tag(1)
            
            ToolsView()
                .tabItem {
                    Label("Herramientas", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)
        }
        .accentColor(Color.cfPrimary)
        .fullScreenCover(isPresented: $appState.showCamera) {
            CameraPickerView()
                .environmentObject(appState)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $appState.showProcessing) {
            ProcessingView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.showResults) {
            ResultsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showExplanation) {
            ExplanationView()
                .environmentObject(appState)
        }
    }
}
