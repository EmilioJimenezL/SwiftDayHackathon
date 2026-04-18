import SwiftUI

// MARK: - Capture
struct Capture: Identifiable {
    let id: UUID
    var title: String
    var timestamp: Date
    var imageData: Data?
    var extractedText: String
    var detectedFormulas: [MathFormula]
    var explanations: [ExplanationBlock]
    
    init(
        id: UUID = UUID(),
        title: String,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        extractedText: String = "",
        detectedFormulas: [MathFormula] = [],
        explanations: [ExplanationBlock] = []
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.imageData = imageData
        self.extractedText = extractedText
        self.detectedFormulas = detectedFormulas
        self.explanations = explanations
    }
    
    var timeAgoString: String {
        let diff = Date().timeIntervalSince(timestamp)
        if diff < 3600 { return "Hace \(Int(diff / 60)) min" }
        if diff < 86400 { return "Hace \(Int(diff / 3600)) h" }
        return "Ayer"
    }
}

// MARK: - Math Formula
struct MathFormula: Identifiable {
    let id: UUID
    var rawText: String
    var steps: [SolutionStep]
    
    init(id: UUID = UUID(), rawText: String, steps: [SolutionStep] = []) {
        self.id = id
        self.rawText = rawText
        self.steps = steps
    }
}

struct SolutionStep: Identifiable {
    let id: UUID
    var number: Int
    var description: String
    var expression: String
    
    init(id: UUID = UUID(), number: Int, description: String, expression: String) {
        self.id = id
        self.number = number
        self.description = description
        self.expression = expression
    }
}

// MARK: - Explanation Block
struct ExplanationBlock: Identifiable {
    let id: UUID
    var number: Int?
    var title: String
    var body: String
    var isCoreIdea: Bool
    var imageName: String?
    
    init(
        id: UUID = UUID(),
        number: Int? = nil,
        title: String,
        body: String,
        isCoreIdea: Bool = false,
        imageName: String? = nil
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.isCoreIdea = isCoreIdea
        self.imageName = imageName
    }
}

// MARK: - Help Option
enum HelpOption: CaseIterable, Identifiable {
    // Text Help
    case briefSummary
    case bulletPoints
    case simpleLanguage
    // Math Help
    case stepByStep
    case breakdown
    
    var id: Self { self }
    
    var category: HelpCategory {
        switch self {
        case .briefSummary, .bulletPoints, .simpleLanguage: return .text
        case .stepByStep, .breakdown: return .math
        }
    }
    var title: String {
        switch self {
        case .briefSummary:  return "Resumen breve"
        case .bulletPoints:  return "Viñetas"
        case .simpleLanguage: return "Lenguaje sencillo"
        case .stepByStep:    return "Paso a paso"
        case .breakdown:     return "Desglose"
        }
    }
    var subtitle: String {
        switch self {
        case .briefSummary:  return "Obtén la idea principal rápido."
        case .bulletPoints:  return "Puntos clave en lista simple."
        case .simpleLanguage: return "Reescribe el texto complejo en palabras fáciles."
        case .stepByStep:    return "Cada operación matemática desglosada."
        case .breakdown:     return "Entiende cada parte de la ecuación."
        }
    }
    var icon: String {
        switch self {
        case .briefSummary:  return "doc.text.fill"
        case .bulletPoints:  return "list.bullet"
        case .simpleLanguage: return "character.bubble"
        case .stepByStep:    return "list.number"
        case .breakdown:     return "function"
        }
    }
}

enum HelpCategory {
    case text, math
    var label: String { self == .text ? "Ayuda de texto" : "Ayuda matemática" }
}

// MARK: - Processing State
enum ProcessingState {
    case idle
    case capturing
    case processing(message: String)
    case results
    case helpSelection
    case explanation
    case error(String)
}

// MARK: - Mock Data
extension Capture {
    static let mockData: [Capture] = [
        Capture(
            title: "Análisis Menú Cafetería",
            timestamp: Date().addingTimeInterval(-7200),
            extractedText: "El zorro marrón rápido salta sobre el perro perezoso. Este es un texto de muestra extraído desde la imagen. Por favor revisa y edita si es necesario.",
            detectedFormulas: [
                MathFormula(
                    rawText: "f(x) = 2x² + 3x - 1",
                    steps: [
                        SolutionStep(number: 1, description: "Identificamos los coeficientes", expression: "a=2, b=3, c=-1"),
                        SolutionStep(number: 2, description: "Aplicamos la fórmula cuadrática", expression: "x = (-b ± √(b²-4ac)) / 2a"),
                        SolutionStep(number: 3, description: "Sustituimos valores", expression: "x = (-3 ± √(9+8)) / 4"),
                        SolutionStep(number: 4, description: "Resultado", expression: "x = (-3 ± √17) / 4")
                    ]
                )
            ],
            explanations: [
                ExplanationBlock(title: "Idea Central", body: "La fotosíntesis es cómo las plantas producen su propio alimento. Usan la luz solar, el agua y el aire para crear azúcar, lo que les ayuda a crecer y en el proceso liberan el oxígeno que respiramos.", isCoreIdea: true),
                ExplanationBlock(number: 1, title: "Captando la Luz Solar", body: "Las hojas de la planta capturan la luz solar usando un químico verde especial llamado clorofila. Piénsalo como paneles solares en una casa absorbiendo energía del sol."),
                ExplanationBlock(number: 2, title: "Mezclando los Ingredientes", body: "Dentro de la hoja, la planta mezcla la energía del sol con el agua de sus raíces y el dióxido de carbono del aire. Es como hornear un pastel donde la luz solar es el calor del horno.")
            ]
        ),
        Capture(
            title: "Etiqueta Medicamento",
            timestamp: Date().addingTimeInterval(-86400),
            extractedText: "Tomar 1 tableta cada 8 horas con alimentos.",
            detectedFormulas: []
        )
    ]
}
