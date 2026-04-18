# LexiScan — Capa de Percepción (OCR)
### Módulo de Inteligencia Artificial · Hackathon Apple

---

## Índice

1. [¿Qué hace este módulo?](#1-qué-hace-este-módulo)
2. [Estructura de archivos](#2-estructura-de-archivos)
3. [Arquitectura MVVM](#3-arquitectura-mvvm)
4. [Flujo de datos completo](#4-flujo-de-datos-completo)
5. [Archivos — explicación detallada](#5-archivos--explicación-detallada)
6. [Modelo de datos: `RecognizedBlock`](#6-modelo-de-datos-recognizedblock)
7. [El protocolo `InformationProcessor`](#7-el-protocolo-informationprocessor)
8. [Integración en Xcode](#8-integración-en-xcode)
9. [Permisos requeridos en Info.plist](#9-permisos-requeridos-en-infoplist)
10. [Guía de uso para el equipo de frontend](#10-guía-de-uso-para-el-equipo-de-frontend)
11. [Hoja de ruta: siguientes fases de ML](#11-hoja-de-ruta-siguientes-fases-de-ml)

---

## 1. ¿Qué hace este módulo?

Este módulo implementa la **Capa de Percepción** de la app de accesibilidad para dislexia/discalculia. Su responsabilidad es:

> **Recibir una imagen** (foto de pizarrón, PDF renderizado, captura de presentación) → **extraer todo el texto visible** → **devolver cada línea con sus metadatos** (posición en la imagen, nivel de confianza, orden de lectura).

El módulo **no interpreta** el texto (eso es trabajo de la Capa de Comprensión con Foundation Models, que va después). Solo percibe y captura con la máxima fidelidad posible.

---

## 2. Estructura de archivos

```
LexiScan/
├── LexiScanApp.swift              # Punto de entrada de la app (@main)
│
├── Models/
│   └── RecognizedBlock.swift      # Modelo de datos + protocolo InformationProcessor
│
├── Services/
│   └── OCRProcessor.swift         # Lógica de Vision Framework (OCR)
│
├── ViewModels/
│   └── ScanViewModel.swift        # Coordinador de estado (MVVM)
│
├── Views/
│   ├── ScanView.swift             # Vista principal
│   ├── ImagePickerView.swift      # Puente UIKit → SwiftUI (cámara/galería)
│   ├── BoundingBoxOverlay.swift   # Overlay visual de bounding boxes
│   └── DebugMetadataView.swift    # Panel técnico de debug
│
└── PrivacyPermissions.plist       # Claves NSCamera / NSPhotoLibrary para Info.plist
```

---

## 3. Arquitectura MVVM

```
┌─────────────────────────────────────────────────────────┐
│                        ScanView                         │  ← SwiftUI (UI pura, sin lógica)
│  ImagePickerView  │  BoundingBoxOverlay  │  DebugView   │
└────────────────────────────┬────────────────────────────┘
                             │  @StateObject / @Published
                             ▼
┌─────────────────────────────────────────────────────────┐
│                     ScanViewModel                       │  ← Coordinador de estado
│  - Estado publicado (@Published)                        │
│  - Llama a OCRProcessor                                 │
│  - Gancho para InformationProcessor (fase 2)            │
└────────────────────────────┬────────────────────────────┘
                             │  Protocol: OCRProcessing
                             ▼
┌─────────────────────────────────────────────────────────┐
│                     OCRProcessor                        │  ← Servicio puro (sin UI)
│  - VNRecognizeTextRequest (.accurate)                   │
│  - Bounding boxes + confidence                          │
│  - Ordenamiento por posición Y                          │
└─────────────────────────────────────────────────────────┘
                             │  devuelve
                             ▼
                    [RecognizedBlock]                        ← Modelo de datos
```

**¿Por qué MVVM aquí?**

- **View** solo sabe mostrar datos y reaccionar a gestos — nunca importa Vision.
- **ViewModel** es el único que conoce tanto la UI como los servicios; centraliza el estado.
- **Service (OCRProcessor)** es independiente de SwiftUI; se puede testear sin simulador y reemplazar sin tocar la View.

---

## 4. Flujo de datos completo

```
Usuario toca "Cámara" o "Galería"
        │
        ▼
ScanView.selectPhoto(from:)
        │
        ▼
showImagePicker = true → presenta ImagePickerView (sheet)
        │
        ▼ (usuario confirma foto)
ImagePickerView.Coordinator.didFinishPicking → selectedImage = UIImage
        │
        ▼
ScanView detecta cambio → llama viewModel.processImage(image)
        │
        ▼
ScanViewModel.runOCR(on:)
    isProcessing = true
        │
        ▼
OCRProcessor.recognize(image:)
    ├── CIImage(image:)
    ├── VNRecognizeTextRequest (nivel .accurate, idiomas es/en)
    ├── VNImageRequestHandler.perform([request])
    └── buildBlocks(from: observations)
            ├── Ordena por Y descendente (origen Vision = inferior-izquierdo)
            └── topCandidates(1) → texto + confidence
        │
        ▼
[RecognizedBlock] → viewModel.recognizedBlocks (publica)
        │
        ▼
ScanView re-renderiza:
    ├── BoundingBoxOverlay sobre la imagen
    ├── Lista de texto extraído (orden de lectura)
    └── DebugMetadataView (IDs, BBox, confidence, tiempo)
```

---

## 5. Archivos — explicación detallada

### `RecognizedBlock.swift` — Modelos

Contiene **dos cosas importantes**:

**a) El struct `RecognizedBlock`**

```swift
struct RecognizedBlock: Identifiable {
    let id: UUID
    let text: String
    let boundingBox: CGRect   // coordenadas Vision [0,1], origen inferior-izquierdo
    let confidence: Float     // 0.0 → 1.0
    let readingOrder: Int     // calculado por posición Y
}
```

El campo `boundingBox` no es decorativo. La posición del texto en la imagen es la primera señal para detectar estructura sin ML:

| Heurística geométrica | Significado probable |
|---|---|
| Bloque en tercio superior, altura > 0.06 | Título |
| Sangría izquierda pronunciada (x > 0.15) | Bullet / lista |
| Posición centrada horizontal | Subtítulo |
| Texto pequeño y denso | Cuerpo / párrafo |

**b) El protocolo `InformationProcessor`**

```swift
protocol InformationProcessor {
    func process(blocks: [RecognizedBlock]) async throws -> any Sendable
}
```

Este protocolo es el **contrato de la próxima fase**. Cualquier componente que lo conforme (Foundation Models, Core ML, un mock) puede ser inyectado en el `ScanViewModel` sin modificar nada más.

---

### `OCRProcessor.swift` — Servicio de Vision

Toda la lógica de Vision Framework vive aquí y **solo aquí**.

**Configuración clave:**

```swift
request.recognitionLevel = .accurate
// .accurate usa el motor neural completo. Es más lento que .fast pero
// necesario para escritura manual en pizarrón donde las letras no son perfectas.

request.recognitionLanguages = ["es-MX", "es", "en-US"]
// Prioridad: español mexicano → español genérico → inglés
// Para el hackathon, este orden es correcto. Se puede hacer configurable.

request.minimumTextHeight = 0.015
// Filtra "texto" de menos del 1.5% de la altura de la imagen — elimina ruido visual.

request.usesLanguageCorrection = true
// Vision aplica un modelo de lenguaje interno para corregir OCR ambiguo.
// Ayuda con palabras de pizarrón mal escritas o poco nítidas.
```

**Transformación de coordenadas:**

Vision devuelve `boundingBox` con origen en la esquina **inferior-izquierda**. SwiftUI y UIKit usan origen **superior-izquierdo**. La conversión se hace en `BoundingBoxOverlay.swift`:

```swift
// Vision  →  SwiftUI
y_swiftui = (1 - y_vision - height_vision) * containerHeight
```

---

### `ScanViewModel.swift` — Coordinador

El ViewModel orquesta el flujo y publica el estado. Los campos `@Published` que más usará el frontend:

| Campo | Tipo | Descripción |
|---|---|---|
| `selectedImage` | `UIImage?` | Imagen activa en pantalla |
| `recognizedBlocks` | `[RecognizedBlock]` | Bloques OCR con metadatos |
| `isProcessing` | `Bool` | Mostrar spinner |
| `errorMessage` | `String?` | Mensaje de error si falla Vision |
| `processingTimeMs` | `Double` | Tiempo de OCR en ms (para debug) |
| `averageConfidence` | `Float` | Confianza promedio de la sesión |

Propiedades computadas útiles:

```swift
viewModel.fullExtractedText      // String con todo el texto unido por \n
viewModel.highConfidenceBlocks   // Bloques con confidence ≥ 0.7
viewModel.lowConfidenceBlocks    // Bloques con confidence < 0.7
```

---

### `ImagePickerView.swift` — Puente UIKit → SwiftUI

Envuelve `UIImagePickerController` usando `UIViewControllerRepresentable`.

- Soporta `.camera` y `.photoLibrary` con el mismo componente.
- `allowsEditing = true` permite al usuario enderezar o recortar la foto del pizarrón antes de procesar — mejora el OCR notablemente.
- El `Coordinator` es el único objeto que importa UIKit; la View y el ViewModel no lo ven.

---

### `BoundingBoxOverlay.swift` — Overlay visual

Dibuja rectángulos de colores sobre la imagen según la confianza de cada bloque:

| Color | Confianza | Interpretación |
|---|---|---|
| 🟢 Verde | ≥ 85% | Texto claro, muy confiable |
| 🟡 Amarillo | 60–85% | Texto difícil / escritura manual |
| 🔴 Rojo | < 60% | Posible ruido, revisar manualmente |

Los badges muestran el porcentaje exacto encima de cada rectángulo.

---

### `DebugMetadataView.swift` — Panel de debug

Panel colapsable que muestra:
- Cantidad de bloques detectados
- Tiempo de procesamiento OCR
- Confianza promedio
- Por cada bloque (expandible al tocar): UUID parcial, coordenadas BBox, confianza exacta

Este componente es solo para desarrollo y demos del hackathon. En producción, los metadatos se consumen internamente.

---

## 6. Modelo de datos: `RecognizedBlock`

```swift
// Ejemplo de lo que devuelve OCRProcessor para la frase "Fotosíntesis" en la esquina superior
RecognizedBlock(
    id: UUID(),                             // "3F2504E0-..."
    text: "Fotosíntesis",
    boundingBox: CGRect(                    // Coordenadas Vision normalizadas [0,1]
        x: 0.05,                            // 5% desde el borde izquierdo
        y: 0.88,                            // 88% desde el borde inferior (= cerca arriba)
        width: 0.35,                        // ocupa 35% del ancho
        height: 0.07                        // ocupa 7% de la altura → letra grande → posible título
    ),
    confidence: 0.94,                       // 94% de confianza
    readingOrder: 0                         // Primer bloque en orden de lectura
)
```

---

## 7. El protocolo `InformationProcessor`

Este protocolo es el punto de extensión para la **Fase 2 (Capa de Comprensión)**. Para agregar Foundation Models:

```swift
// Fase 2: crear este archivo en Services/
import FoundationModels  // iOS 26+ / macOS 26+

struct FoundationModelsProcessor: InformationProcessor {
    func process(blocks: [RecognizedBlock]) async throws -> any Sendable {
        let session = LanguageModelSession()
        let orderedText = blocks
            .sorted { $0.readingOrder < $1.readingOrder }
            .map(\.text)
            .joined(separator: "\n")

        let prompt = """
        El siguiente texto fue extraído de un pizarrón escolar.
        Clasifica cada línea como: titulo, subtitulo, definicion, ejemplo, o cuerpo.
        Devuelve JSON con estructura { bloques: [{ texto, tipo }] }.

        Texto:
        \(orderedText)
        """

        return try await session.respond(to: prompt)
    }
}

// Inyección en ScanViewModel (en LexiScanApp.swift o en la View padre):
let viewModel = ScanViewModel()
viewModel.informationProcessor = FoundationModelsProcessor()
```

**El ViewModel ya tiene el gancho listo** — solo se inyecta el procesador y el flujo funciona automáticamente.

---

## 8. Integración en Xcode

### Crear el proyecto

1. Xcode → **File > New > Project** → **App**
2. Interface: **SwiftUI**, Language: **Swift**
3. Nombre: `LexiScan`, Bundle ID: `com.tuequipo.lexiscan`
4. Mínimo deployment target: **iOS 17.0** (para tener las APIs modernas de Vision)

### Agregar los archivos

Arrastra los archivos al proyecto en la estructura de grupos:

```
LexiScan/
├── LexiScanApp.swift
├── Models/        → RecognizedBlock.swift
├── Services/      → OCRProcessor.swift
├── ViewModels/    → ScanViewModel.swift
└── Views/         → ScanView.swift
                   → ImagePickerView.swift
                   → BoundingBoxOverlay.swift
                   → DebugMetadataView.swift
```

### Frameworks requeridos

Vision y CoreGraphics son frameworks del sistema — **no se necesita agregar nada** en "Frameworks, Libraries, and Embedded Content". Xcode los resuelve automáticamente con los `import`.

---

## 9. Permisos requeridos en Info.plist

Agrega estas dos claves en el `Info.plist` del target (o en la sección "Privacy" de la configuración del target en Xcode):

| Clave | Valor sugerido |
|---|---|
| `NSCameraUsageDescription` | "LexiScan necesita acceso a la cámara para fotografiar pizarrones y documentos." |
| `NSPhotoLibraryUsageDescription` | "LexiScan necesita acceso a tu galería para seleccionar imágenes de pizarrones y apuntes." |

Sin estas claves, la app crasheará al intentar abrir la cámara o la galería.

---

## 10. Guía de uso para el equipo de frontend

### Lo que obtienes de este módulo

Cuando el usuario selecciona una imagen, el `ScanViewModel` publica automáticamente:

```swift
// Leer todos los bloques con metadatos completos:
viewModel.recognizedBlocks   // [RecognizedBlock]

// Leer solo el texto unido (para mostrar en una Text view simple):
viewModel.fullExtractedText  // String

// Estado de carga:
viewModel.isProcessing       // Bool → mostrar spinner

// Error si algo salió mal:
viewModel.errorMessage       // String? → mostrar alerta
```

### Cómo agregar una vista personalizada

Si el equipo de frontend quiere una vista de resultados diferente a la incluida:

```swift
struct MiVistaPersonalizada: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        VStack {
            // Imagen
            if let img = viewModel.selectedImage {
                Image(uiImage: img).resizable().scaledToFit()
            }

            // Texto extraído en orden de lectura
            ForEach(viewModel.recognizedBlocks.sorted { $0.readingOrder < $1.readingOrder }) { block in
                Text(block.text)
                    .opacity(Double(block.confidence))  // opacidad proporcional a confianza
            }
        }
    }
}
```

### Inyectar un ViewModel personalizado

Si se necesita configurar el procesador OCR (por ejemplo, cambiar idiomas):

```swift
// En LexiScanApp.swift o en la View padre:
let processor = OCRProcessor()
processor.recognitionLanguages = ["es-MX", "en-US"]
processor.minimumTextHeight = 0.02

let viewModel = ScanViewModel(ocrProcessor: processor)

// Pasar el viewModel a la vista:
ScanView(viewModel: viewModel)  // ← requiere cambiar @StateObject por @ObservedObject
```

---

## 11. Hoja de ruta: siguientes fases de ML

| Fase | Componente | Herramienta Apple | Estado |
|---|---|---|---|
| ✅ **Fase 1** | Extracción OCR + metadatos | Vision Framework | **Completo** |
| 🔜 **Fase 2** | Clasificación semántica (título/subtítulo/cuerpo) | Foundation Models (iOS 26) | Listo para integrar |
| 🔜 **Fase 3** | Detección de diagramas y fórmulas matemáticas | Vision + Core ML | Por diseñar |
| 🔜 **Fase 4** | Renderizado accesible (fuente, espaciado, color) | SwiftUI + Core Text | Por diseñar |
| 🔜 **Fase 5** | Clasificador de layout fine-tuneado en pizarrones | Create ML Image Classifier | Requiere datos reales |

---

## Dependencias externas

**Ninguna.** Este módulo usa exclusivamente frameworks nativos de Apple:

- `Vision` — OCR
- `SwiftUI` — UI
- `UIKit` — ImagePickerController
- `CoreGraphics` — CGRect para bounding boxes
- `Foundation` — UUID, async/await

No se requiere instalar pods, SPM packages, ni configurar nada adicional.

---

*Desarrollado para el Hackathon Apple · Proyecto de Accesibilidad para Dislexia/Discalculia*
