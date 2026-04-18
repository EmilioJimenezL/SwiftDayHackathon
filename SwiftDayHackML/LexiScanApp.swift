// MARK: - LexiScanApp.swift
// Punto de entrada de la aplicación.
//
// Responsabilidad de este archivo: construir el grafo de dependencias completo
// antes de presentar cualquier vista. Toda la inyección de servicios ocurre aquí,
// lo que significa que ni ScanView ni ScanViewModel necesitan saber qué
// implementación concreta de InformationProcessor está activa.
//
// Para deshabilitar Foundation Models (demo sin Apple Intelligence, o iOS < 26):
//   comentar la línea `vm.informationProcessor = FoundationModelsProcessor()`
//   La app seguirá funcionando con solo la Capa de Percepción (OCR).

import SwiftUI

@main
struct LexiScanApp: App {

    // Construimos el ViewModel una sola vez como @StateObject del App,
    // así su ciclo de vida está ligado a la app entera y no a una vista.
    // Esto evita que se destruya y recree al navegar.
    @StateObject private var viewModel: ScanViewModel = {
        let vm = ScanViewModel()

        // ── Fase 2: activar Foundation Models ──────────────────────────────
        // Requiere iOS 26+ y dispositivo con Apple Intelligence habilitado.
        // Comentar esta línea para usar solo OCR (Fase 1).
        vm.informationProcessor = FoundationModelsProcessor()

        return vm
    }()

    var body: some Scene {
        WindowGroup {
            ScanView(viewModel: viewModel)
        }
    }
}
