# LexiScan — Motor de IA
### Módulo de Inteligencia Artificial · Hackathon Apple

---

## Índice

1. [Visión general del módulo](#1-visión-general-del-módulo)
2. [Estructura de archivos](#2-estructura-de-archivos)
3. [Arquitectura MVVM y capas de IA](#3-arquitectura-mvvm-y-capas-de-ia)
4. [Flujo de datos completo](#4-flujo-de-datos-completo)
5. [Fase 1 — Capa de Percepción (OCR)](#5-fase-1--capa-de-percepción-ocr)
6. [Fase 2 — Capa de Comprensión (Foundation Models)](#6-fase-2--capa-de-comprensión-foundation-models)
7. [Modelos de datos](#7-modelos-de-datos)
8. [ScanViewModel — Estado compartido](#8-scanviewmodel--estado-compartido)
9. [Vistas y componentes UI](#9-vistas-y-componentes-ui)
10. [Integración en Xcode](#10-integración-en-xcode)
11. [Permisos requeridos en Info.plist](#11-permisos-requeridos-en-infoplist)
12. [Guía de uso para el equipo de frontend](#12-guía-de-uso-para-el-equipo-de-frontend)
13. [Hoja de ruta](#13-hoja-de-ruta)
14. [Dependencias externas](#14-dependencias-externas)

---

## 1. Visión general del módulo

LexiScan transforma imágenes de pizarrones, documentos y presentaciones en contenido semántico estructurado y accesible para personas con dislexia y discalculia. El procesamiento ocurre en **dos capas secuenciales**, ambas completamente on-device:

| Capa | Archivo | Tecnología | Entrada → Salida |
|---|---|---|---|
| **Percepción** | `OCRProcessor` | Vision Framework | `UIImage` → `[RecognizedBlock]` |
| **Comprensión** | `FoundationModelsProcessor` | Foundation Models (iOS 26+) | `[RecognizedBlock]` → `StructuredContent` |

Las dos capas están desacopladas mediante el protocolo `InformationProcessor`. La Capa de Percepción puede funcionar de forma independiente (útil para tests o dispositivos sin Apple Intelligence). La Capa de Comprensión se activa únicamente cuando se inyecta un procesador en el ViewModel.

---

## 2. Estructura de archivos

```
LexiScan/
├── LexiScanApp.swift                    # Punto de entrada (@main)
│
├── Models/
│   ├── RecognizedBlock.swift            # Modelo OCR + protocolo InformationProcessor
│   └── StructuredContent.swift          # Modelo semántico de salida (Fase 2)
│
├── Services/
│   ├── OCRProcessor.swift               # Vision Framework — Fase 1
│   └── FoundationModelsProcessor.swift  # Foundation Models — Fase 2
│
├── ViewModels/
│   └── ScanViewModel.swift              # Coordinador de estado (MVVM)
│
├── Views/
│   ├── ScanView.swift                   # Vista principal
│   ├── ImagePickerView.swift            # Puente UIKit → SwiftUI (cámara/galería)
│   ├── BoundingBoxOverlay.swift         # Overlay visual de bounding boxes
│   └── DebugMetadataView.swift          # Panel técnico de debug
│
└── PrivacyPermissions.plist             # Claves NSCamera / NSPhotoLibrary
```

---

## 3. Arquitectura MVVM y capas de IA

```
┌──────────────────────────────────────────────────────────────┐
│                          ScanView                            │  ← SwiftUI (sin lógica)
│   ImagePickerView │ BoundingBoxOverlay │ DebugMetadataView   │
└───────────────────────────────┬──────────────────────────────┘
                                │  @StateObject / @Published
                                ▼
┌──────────────────────────────────────────────────────────────┐
│                       ScanViewModel                          │  ← Coordinador de estado
│  @Published: recognizedBlocks, structuredContent,            │
│              isProcessing, isStructuring, errorMessage       │
└──────┬────────────────────────────────────────┬─────────────┘
       │ OCRProcessing (protocol)               │ InformationProcessor (protocol)
       ▼                                        ▼
┌─────────────────────┐              ┌──────────────────────────────┐
│    OCRProcessor     │              │  FoundationModelsProcessor   │
│  Vision Framework   │              │  Foundation Models (iOS 26+) │
│  .accurate OCR      │              │  5-step pipeline             │
│  bounding boxes     │              │  on-device LLM               │
└─────────┬───────────┘              └──────────────┬───────────────┘
          │ devuelve                                 │ devuelve
          ▼                                         ▼
   [RecognizedBlock]                         StructuredContent
```

**¿Por qué MVVM con protocolos?**

- La **View** nunca importa Vision ni FoundationModels — solo observa estado.
- El **ViewModel** orquesta el pipeline secuencial y aísla los errores de cada capa.
- Los **Servicios** son clases `final` sin dependencias de UI, testeables en aislamiento.
- Los **protocolos** (`OCRProcessing`, `InformationProcessor`) permiten sustituir cualquier servicio por un mock sin tocar el ViewModel.

---

## 4. Flujo de datos completo

```
Usuario selecciona imagen (cámara o galería)
        │
        ▼
viewModel.processImage(UIImage)
        │
        ├─────── FASE 1: OCR ───────────────────────────────────────────
        │
        ▼
OCRProcessor.recognize(image:)
  ├── CIImage desde UIImage
  ├── VNRecognizeTextRequest (.accurate, es-MX/es/en-US)
  ├── VNImageRequestHandler.perform([request])
  └── buildBlocks(observations)
        ├── Ordena por Y desc (origen Vision = inferior-izquierdo)
        └── topCandidates(1) → texto + confidence + boundingBox
        │
        ▼
[RecognizedBlock] ──→ viewModel.recognizedBlocks (@Published)
                       viewModel.isProcessing = false
                  ──→ UI re-renderiza: overlay + lista de texto
        │
        ├─────── FASE 2: COMPRENSIÓN (si hay InformationProcessor) ─────
        │
        ▼
FoundationModelsProcessor.process(blocks:)
  ├── 1. Filtrado: descarta confidence < 0.50, marca 0.50–0.65 como DUDOSO
  ├── 2. Clasificación geométrica: boundingBox.height → TITULO/SUBTITULO/CUERPO
  ├── 3. Serializa bloques con coordenadas en user prompt
  ├── 4. LanguageModelSession.respond(to:) → JSON string
  └── 5. JSONDecoder → StructuredContent + ProcessingMetadata
        │
        ▼
StructuredContent ──→ viewModel.structuredContent (@Published)
                       viewModel.isStructuring = false
                  ──→ UI renderiza vista accesible
```

---

## 5. Fase 1 — Capa de Percepción (OCR)

### `OCRProcessor.swift`

Toda la lógica de Vision Framework vive aquí y **solo aquí**. El servicio es `final class` sin dependencias de UI.

**Configuración clave y su justificación:**

```swift
request.recognitionLevel = .accurate
// Usa el motor neural completo. Imprescindible para escritura manual
// en pizarrón donde las letras son irregulares o el fondo es ruidoso.
// Alternativa .fast para iteraciones de debug si la velocidad es prioritaria.

request.recognitionLanguages = ["es-MX", "es", "en-US"]
// Prioridad: español mexicano → español genérico → inglés.
// El orden importa: Vision usa el primer idioma como modelo principal.

request.minimumTextHeight = 0.015
// Descarta "texto" que ocupa menos del 1.5% de la altura de imagen.
// Elimina artefactos visuales y ruido de compresión JPEG.

request.usesLanguageCorrection = true
// Vision aplica un modelo de lenguaje interno para resolver OCR ambiguo.
// Especialmente útil para palabras técnicas escritas con errores de tiza.
```

**Transformación de coordenadas — detalle crítico:**

Vision devuelve `boundingBox` con origen en la esquina **inferior-izquierda** (sistema matemático). SwiftUI y UIKit usan origen **superior-izquierdo** (sistema de pantalla). La conversión se aplica en `BoundingBoxOverlay.swift`:

```
Sistema Vision:           Sistema SwiftUI:
(0,1) ─────── (1,1)      (0,0) ─────── (1,0)
  │                │        │                │
  │                │   →    │                │
(0,0) ─────── (1,0)      (0,1) ─────── (1,1)

Fórmula: y_swiftui = (1 - y_vision - height_vision) * containerHeight
```

### Protocolo `OCRProcessing`

```swift
protocol OCRProcessing {
    func recognize(image: UIImage) async throws -> [RecognizedBlock]
}
```

Permite sustituir `OCRProcessor` por un mock en tests, o en el futuro por un motor Core ML fine-tuneado para pizarrones, sin modificar el ViewModel.

---

## 6. Fase 2 — Capa de Comprensión (Foundation Models)

### `FoundationModelsProcessor.swift`

Transforma `[RecognizedBlock]` en `StructuredContent` mediante un pipeline de 5 pasos usando el modelo de lenguaje on-device de Apple.

**¿Por qué Foundation Models y no una API externa?** Ningún dato educativo sale del dispositivo del alumno, no hay dependencia de red (demos confiables en el WiFi del hackathon), y la privacidad está alineada con usuarios vulnerables.

### Pipeline de 5 pasos

**Paso 1 — Filtrado por confianza**

| Rango de confidence | Acción | Etiqueta en prompt |
|---|---|---|
| < 0.50 | Descarte total | No aparece |
| 0.50 – 0.65 | Incluido con advertencia | `DUDOSO` |
| > 0.65 | Clasificación geométrica | Rol por geometría |

**Paso 2 — Clasificación heurística por geometría**

| `boundingBox.height` normalizado | Rol | Etiqueta en prompt |
|---|---|---|
| ≥ 0.06 | Título principal | `TITULO_PRINCIPAL` |
| 0.035 – 0.06 | Subtítulo | `SUBTITULO` |
| < 0.035 | Cuerpo | `CUERPO` |

Los umbrales son propiedades `var` configurables en la instancia del procesador.

**Paso 3 — Serialización del prompt con contexto espacial**

```
[TITULO_PRINCIPAL | orden:0 | y_norm:0.921 | alto_norm:0.072 | confianza:94%] Fotosíntesis
[SUBTITULO | orden:1 | y_norm:0.741 | alto_norm:0.038 | confianza:88%] Proceso en cloroplastos
[CUERPO | orden:2 | y_norm:0.612 | alto_norm:0.021 | confianza:91%] La luz solar se convierte en glucosa
[DUDOSO | orden:3 | y_norm:0.501 | alto_norm:0.019 | confianza:57%] CO2 + H2O → ...
```

Incluir `y_norm` y `alto_norm` permite al modelo razonar sobre jerarquía visual sin ver la imagen.

**Paso 4 — Llamada a Foundation Models**

```swift
let session = LanguageModelSession(instructions: systemPrompt)
let response = try await session.respond(to: userPrompt)
```

El system prompt define 7 reglas de accesibilidad: jerarquía, simplificación lingüística (con preservación de terminología técnica), extracción de matemáticas, manejo de bloques dudosos, formato del resumen, conceptos clave, y salida JSON pura.

**Paso 5 — Decodificación vía DTO intermedio**

El JSON del modelo se decodifica en un `StructuredContentDTO` privado (sin `processingMetadata`) y luego se ensambla el `StructuredContent` final añadiendo los metadatos calculados localmente. Incluye limpieza defensiva por si el modelo envuelve el JSON en backticks.

---

## 7. Modelos de datos

### `RecognizedBlock` — salida de Fase 1

```swift
struct RecognizedBlock: Identifiable {
    let id: UUID             // identidad única para SwiftUI y correlación entre fases
    let text: String         // texto transcrito por Vision
    let boundingBox: CGRect  // coordenadas normalizadas [0,1], origen inferior-izquierdo
    let confidence: Float    // 0.0 → 1.0, nativo de VNRecognizedText
    let readingOrder: Int    // índice calculado por posición Y descendente
}
```

### `StructuredContent` — salida de Fase 2

```swift
struct StructuredContent: Codable, Sendable {
    let mainTitle: String                    // título principal del pizarrón
    let summary: String                      // resumen de exactamente 2 oraciones
    let sections: [Section]                  // secciones con título + viñetas + confianza
    let keyConcepts: [String]                // 3–7 términos clave
    let mathFound: [String]?                 // fórmulas; nil si no hay matemáticas
    let processingMetadata: ProcessingMetadata
}

struct Section: Codable, Sendable {
    let title: String            // encabezado de la sección
    let bullets: [String]        // contenido en lenguaje simple (terminología intacta)
    let confidenceLevel: Float   // confianza promedio de los bloques OCR de la sección
}

struct ProcessingMetadata: Codable, Sendable {
    let totalBlocksReceived: Int   // bloques recibidos del OCR
    let blocksDiscarded: Int       // descartados por confidence < umbral
    let blocksFlagged: Int         // marcados DUDOSO
    let discardThreshold: Float    // umbral usado
    var processingTimeMs: Double   // tiempo total de Fase 2 en ms
}
```

### Protocolo `InformationProcessor`

```swift
protocol InformationProcessor {
    func process(blocks: [RecognizedBlock]) async throws -> any Sendable
}
```

El tipo `any Sendable` mantiene el protocolo desacoplado de `StructuredContent`. Un segundo procesador futuro puede devolver su propio tipo sin modificar el protocolo ni el ViewModel.

---

## 8. ScanViewModel — Estado compartido

**Propiedades `@Published` disponibles para la View:**

| Propiedad | Tipo | Disponible desde | Descripción |
|---|---|---|---|
| `selectedImage` | `UIImage?` | Inmediatamente | Imagen activa en pantalla |
| `isProcessing` | `Bool` | Inicio de Fase 1 | Spinner de OCR |
| `recognizedBlocks` | `[RecognizedBlock]` | Fin de Fase 1 | Bloques crudos con metadatos |
| `isStructuring` | `Bool` | Inicio de Fase 2 | Spinner de LLM |
| `structuredContent` | `StructuredContent?` | Fin de Fase 2 | Contenido semántico final |
| `errorMessage` | `String?` | Cualquier fase | Error de OCR o LLM (prefijado) |
| `processingTimeMs` | `Double` | Fin de Fase 1 | Tiempo OCR en ms |
| `averageConfidence` | `Float` | Fin de Fase 1 | Confianza promedio OCR |

**Propiedades computadas de solo lectura:**

```swift
viewModel.fullExtractedText      // todos los bloques unidos por \n, en readingOrder
viewModel.highConfidenceBlocks   // bloques con confidence ≥ 0.7
viewModel.lowConfidenceBlocks    // bloques con confidence < 0.7
```

**Nota sobre concurrencia (Swift 6):** la clase no lleva `@MainActor` a nivel de tipo para evitar conflictos con `@StateObject`. Cada método que muta `@Published` lo lleva de forma explícita. Los errores de Fase 2 no borran los resultados de Fase 1.

---

## 9. Vistas y componentes UI

### `ScanView.swift`
Vista principal. Presenta imagen con overlay → botones → spinner/error → texto crudo (Fase 1) → panel de debug. El texto crudo es visible mientras el LLM procesa, evitando pantalla en blanco.

### `ImagePickerView.swift`
Puente `UIViewControllerRepresentable` para `UIImagePickerController`. Soporta cámara y galería. `allowsEditing = true` permite recortar o enderezar la foto antes de procesar.

### `BoundingBoxOverlay.swift`
Dibuja rectángulos de Vision sobre la imagen con código de colores: 🟢 ≥ 85%, 🟡 60–85%, 🔴 < 60%. Incluye conversión interna de coordenadas Vision → SwiftUI.

### `DebugMetadataView.swift`
Panel colapsable con estadísticas globales y filas expandibles por bloque. Solo para desarrollo y demos del hackathon.

---

## 10. Integración en Xcode

### Crear el proyecto

1. Xcode → **File > New > Project** → **App**
2. Interface: **SwiftUI**, Language: **Swift**
3. Deployment target: **iOS 26.0** (Foundation Models requiere iOS 26+)

> Para desarrollo con solo Fase 1 (OCR), iOS 17.0 es suficiente. Sube a 26.0 al integrar `FoundationModelsProcessor`.

### Frameworks requeridos

Todos son del sistema — no se configura nada extra en el target:

| Framework | Archivo | Import |
|---|---|---|
| `Vision` | OCRProcessor | `import Vision` |
| `FoundationModels` | FoundationModelsProcessor | `import FoundationModels` |
| `CoreGraphics` | RecognizedBlock, BoundingBoxOverlay | `import CoreGraphics` |
| `SwiftUI` | Todas las vistas | `import SwiftUI` |
| `UIKit` | ImagePickerView | `import UIKit` |

### Activar Apple Intelligence en el simulador

Foundation Models requiere Apple Intelligence habilitado. En el simulador de Xcode 26: **Settings → Apple Intelligence & Siri → Enable Apple Intelligence**.

---

## 11. Permisos requeridos en Info.plist

| Clave | Valor sugerido |
|---|---|
| `NSCameraUsageDescription` | "LexiScan necesita acceso a la cámara para fotografiar pizarrones y documentos." |
| `NSPhotoLibraryUsageDescription` | "LexiScan necesita acceso a tu galería para seleccionar imágenes de pizarrones y apuntes." |

---

## 12. Guía de uso para el equipo de frontend

### Activar el pipeline completo (Fase 1 + Fase 2)

```swift
// En LexiScanApp.swift:
struct LexiScanApp: App {
    var body: some Scene {
        WindowGroup {
            let vm = ScanViewModel()
            vm.informationProcessor = FoundationModelsProcessor()
            return ScanView(viewModel: vm)
        }
    }
}
```

### Observar ambas fases en una vista personalizada

```swift
struct MiVistaAccesible: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        ScrollView {
            // Fase 1: texto crudo disponible en segundos
            if viewModel.isProcessing {
                ProgressView("Leyendo pizarrón…")
            }

            // Fase 2: contenido estructurado (2–8 segundos adicionales)
            if viewModel.isStructuring {
                ProgressView("Organizando contenido…")
            }

            if let content = viewModel.structuredContent {
                Text(content.mainTitle).font(.largeTitle)
                Text(content.summary)

                ForEach(content.sections, id: \.title) { section in
                    Text(section.title).font(.headline)
                    ForEach(section.bullets, id: \.self) { bullet in
                        Text("• \(bullet)")
                    }
                }

                // Fórmulas — mayor espaciado para discalculia
                if let formulas = content.mathFound {
                    ForEach(formulas, id: \.self) { formula in
                        Text(formula)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}
```

### Configurar umbrales del procesador

```swift
let processor = FoundationModelsProcessor()
processor.discardThreshold  = 0.45   // más permisivo con texto poco nítido
processor.dubiousThreshold  = 0.70
processor.h1HeightThreshold = 0.07   // títulos deben ser más grandes
processor.h2HeightThreshold = 0.04

let vm = ScanViewModel()
vm.informationProcessor = processor
```

### Solo OCR (sin LLM)

```swift
// No inyectar informationProcessor
let vm = ScanViewModel()
// structuredContent permanecerá nil; recognizedBlocks funcionará normalmente
```

---

## 13. Hoja de ruta

| Fase | Componente | Tecnología Apple | Estado |
|---|---|---|---|
| ✅ **Fase 1** | Extracción OCR con bounding boxes y confianza | Vision Framework | **Completo** |
| ✅ **Fase 2** | Estructuración semántica accesible on-device | Foundation Models (iOS 26) | **Completo** |
| 🔜 **Fase 3** | Renderizado accesible (fuente, espaciado, contraste) | SwiftUI + Core Text | Pendiente |
| 🔜 **Fase 4** | Detección y segmentación de diagramas vs. texto | Vision + Core ML | Pendiente |
| 🔜 **Fase 5** | Clasificador de layout fine-tuneado en pizarrones | Create ML Image Classifier | Requiere datos |
| 🔜 **Fase 6** | Lectura en voz alta con pausas semánticas | AVSpeechSynthesizer | Pendiente |

---

## 14. Dependencias externas

**Ninguna.** Solo frameworks nativos de Apple: `Vision`, `FoundationModels`, `SwiftUI`, `UIKit`, `CoreGraphics`, `Foundation`. No se requieren pods, SPM packages ni llaves de API.

---

*Desarrollado para el Hackathon Apple · Proyecto de Accesibilidad para Dislexia/Discalculia*
