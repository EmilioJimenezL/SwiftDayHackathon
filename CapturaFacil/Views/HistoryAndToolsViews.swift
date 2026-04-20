import SwiftUI

// MARK: - History View
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedCapture: Capture? = nil

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
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: CFSpacing.cardGap) {
                            ForEach(filtered) { capture in
                                Button(action: { selectedCapture = capture }) {
                                    CaptureCard(capture: capture)
                                        .padding(.horizontal, CFSpacing.base)
                                }
                            }
                        }
                        .padding(.top, CFSpacing.sm)
                        .padding(.bottom, CFSpacing.xl)
                    }
                    .searchable(text: $searchText, prompt: "Buscar capturas...")
                }
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { appState.startCapture() }) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(Color.cfPrimary)
                    }
                }
            }
            .sheet(item: $selectedCapture) { capture in
                CaptureDetailView(capture: capture)
            }
        }
    }

    private var emptyState: some View {
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
    }
}

// MARK: - Capture Detail View
struct CaptureDetailView: View {
    let capture: Capture
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .texto

    enum DetailTab: String, CaseIterable {
        case texto    = "Texto"
        case formula  = "Fórmulas"
        case explicacion = "Explicación"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selector de sección
                Picker("Sección", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(CFSpacing.base)
                .background(Color.cfBackground)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: CFSpacing.cardGap) {
                        switch selectedTab {
                        case .texto:        textoTab
                        case .formula:      formulasTab
                        case .explicacion:  explicacionTab
                        }
                    }
                    .padding(CFSpacing.base)
                }
                .background(Color.cfBackground)
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationTitle(capture.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.cfText3)
                            .font(.system(size: 22))
                    }
                }
            }
        }
    }

    // MARK: - Tab: Texto
    private var textoTab: some View {
        VStack(alignment: .leading, spacing: CFSpacing.sm) {
            // Metadata
            HStack(spacing: CFSpacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(Color.cfText3)
                Text(capture.timestamp.formatted(.dateTime.day().month().year().hour().minute()))
                    .font(CFFont.caption())
                    .foregroundColor(Color.cfText3)
            }

            Divider()

            Text(capture.extractedText.isEmpty ? "Sin texto extraído." : capture.extractedText)
                .font(CFFont.body())
                .foregroundColor(Color.cfText2)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.top, CFSpacing.sm)

            // Acciones
            HStack(spacing: CFSpacing.base) {
                Button(action: { UIPasteboard.general.string = capture.extractedText }) {
                    Label("Copiar", systemImage: "doc.on.doc")
                        .font(CFFont.body(14, weight: .medium))
                        .foregroundColor(Color.cfText2)
                }
                Divider().frame(height: 20)
                Button(action: { }) {
                    Label("Leer en voz alta", systemImage: "speaker.wave.2")
                        .font(CFFont.body(14, weight: .medium))
                        .foregroundColor(Color.cfText2)
                }
                Spacer()
            }
        }
        .padding(CFSpacing.base)
        .background(Color.cfSurface)
        .cornerRadius(CFSpacing.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Tab: Fórmulas
    @ViewBuilder
    private var formulasTab: some View {
        if capture.detectedFormulas.isEmpty {
            emptyTabMessage(
                icon: "function",
                message: "No se detectaron fórmulas en esta captura."
            )
        } else {
            ForEach(capture.detectedFormulas) { formula in
                FormulaCard(formula: formula)
            }
        }
    }

    // MARK: - Tab: Explicación
    @ViewBuilder
    private var explicacionTab: some View {
        if capture.explanations.isEmpty {
            emptyTabMessage(
                icon: "lightbulb",
                message: "No hay explicación generada para esta captura."
            )
        } else {
            ForEach(Array(capture.explanations.enumerated()), id: \.element.id) { index, block in
                ExplanationBlockView(block: block, delay: Double(index) * CFAnimation.stagger)
            }
        }
    }

    private func emptyTabMessage(icon: String, message: String) -> some View {
        VStack(spacing: CFSpacing.base) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Color.cfBorder)
            Text(message)
                .font(CFFont.body())
                .foregroundColor(Color.cfText3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CFSpacing.xl)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("userName")         private var userName         = "Estudiante"
    @AppStorage("preferredFont")    private var preferredFont    = "Sistema"
    @AppStorage("ttsEnabled")       private var ttsEnabled       = true
    @AppStorage("highContrast")     private var highContrast     = false
    @AppStorage("reduceMotion")     private var reduceMotion     = false
    @AppStorage("ocrLanguage")      private var ocrLanguage      = "es-MX"

    private let fontOptions    = ["Sistema", "Atkinson Hyperlegible", "OpenDyslexic"]
    private let languageOptions = ["es-MX", "es", "en-US"]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: CFSpacing.lg) {
                    profileCard
                    accessibilitySection
                    ocrSection
                    appSection
                    versionFooter
                }
                .padding(CFSpacing.base)
                .padding(.bottom, CFSpacing.xl)
            }
            .background(Color.cfBackground.ignoresSafeArea())
            .navigationTitle("Configuración")
        }
    }

    // MARK: - Perfil
    private var profileCard: some View {
        VStack(spacing: CFSpacing.base) {
            // Avatar
            Circle()
                .fill(Color.cfPrimary.opacity(0.12))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(userName.prefix(1).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.cfPrimary)
                )

            VStack(spacing: 4) {
                Text("Hola,")
                    .font(CFFont.body())
                    .foregroundColor(Color.cfText3)

                TextField("Tu nombre", text: $userName)
                    .font(CFFont.heading1())
                    .foregroundColor(Color.cfText1)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
            }

            HStack(spacing: CFSpacing.lg) {
                statBadge(value: "\(appState.captures.count)", label: "Capturas")
                Divider().frame(height: 30)
                statBadge(
                    value: "\(appState.captures.filter { !$0.detectedFormulas.isEmpty }.count)",
                    label: "Con fórmulas"
                )
                Divider().frame(height: 30)
                statBadge(
                    value: "\(appState.captures.filter { !$0.explanations.isEmpty }.count)",
                    label: "Con explicación"
                )
            }
        }
        .padding(CFSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.cfSurface)
        .cornerRadius(CFSpacing.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.cfPrimary)
            Text(label)
                .font(CFFont.caption())
                .foregroundColor(Color.cfText3)
        }
    }

    // MARK: - Accesibilidad
    private var accessibilitySection: some View {
        settingsSection(title: "Accesibilidad", icon: "accessibility") {
            toggleRow(
                icon: "speaker.wave.2.fill",
                color: Color.cfAccent,
                title: "Lectura en voz alta",
                subtitle: "Activa TTS automático al abrir resultados",
                binding: $ttsEnabled
            )
            Divider().padding(.leading, 52)
            toggleRow(
                icon: "circle.lefthalf.filled",
                color: Color(hex: "#5BAD8F"),
                title: "Alto contraste",
                subtitle: "Mayor diferencia entre texto y fondo",
                binding: $highContrast
            )
            Divider().padding(.leading, 52)
            toggleRow(
                icon: "figure.walk",
                color: Color(hex: "#E0924A"),
                title: "Reducir movimiento",
                subtitle: "Desactiva animaciones de transición",
                binding: $reduceMotion
            )
            Divider().padding(.leading, 52)
            pickerRow(
                icon: "textformat",
                color: Color(hex: "#9B6FD8"),
                title: "Tipografía",
                options: fontOptions,
                selection: $preferredFont
            )
        }
    }

    // MARK: - OCR
    private var ocrSection: some View {
        settingsSection(title: "Reconocimiento de texto", icon: "doc.text.viewfinder") {
            pickerRow(
                icon: "globe",
                color: Color.cfAccent,
                title: "Idioma principal",
                options: languageOptions,
                selection: $ocrLanguage
            )
        }
    }

    // MARK: - App
    private var appSection: some View {
        settingsSection(title: "App", icon: "gearshape") {
            actionRow(
                icon: "trash",
                color: Color(hex: "#D85A5A"),
                title: "Borrar historial",
                subtitle: "Elimina todas las capturas guardadas"
            ) {
                appState.captures = []
            }
            Divider().padding(.leading, 52)
            actionRow(
                icon: "square.and.arrow.up",
                color: Color.cfPrimary,
                title: "Exportar datos",
                subtitle: "Próximamente en v1.2"
            ) { }
        }
    }

    // MARK: - Footer
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("CapturaFácil")
                .font(CFFont.body(14, weight: .semibold))
                .foregroundColor(Color.cfText3)
            Text("v1.0.0 · iOS 26 · Apple Intelligence")
                .font(CFFont.caption())
                .foregroundColor(Color.cfText3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CFSpacing.sm)
    }

    // MARK: - Componentes reutilizables de settings

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.sm) {
            Label(title, systemImage: icon)
                .font(CFFont.caption(13, weight: .semibold))
                .foregroundColor(Color.cfText3)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.cfSurface)
            .cornerRadius(CFSpacing.cardRadius)
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
    }

    private func toggleRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: CFSpacing.base) {
            iconBadge(icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(CFFont.body(15, weight: .medium)).foregroundColor(Color.cfText1)
                Text(subtitle).font(CFFont.caption()).foregroundColor(Color.cfText3)
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden().tint(Color.cfAccent)
        }
        .padding(.horizontal, CFSpacing.base)
        .padding(.vertical, 12)
    }

    private func pickerRow(
        icon: String,
        color: Color,
        title: String,
        options: [String],
        selection: Binding<String>
    ) -> some View {
        HStack(spacing: CFSpacing.base) {
            iconBadge(icon, color: color)
            Text(title).font(CFFont.body(15, weight: .medium)).foregroundColor(Color.cfText1)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Color.cfAccent)
        }
        .padding(.horizontal, CFSpacing.base)
        .padding(.vertical, 12)
    }

    private func actionRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: CFSpacing.base) {
                iconBadge(icon, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CFFont.body(15, weight: .medium)).foregroundColor(Color.cfText1)
                    Text(subtitle).font(CFFont.caption()).foregroundColor(Color.cfText3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.cfText3)
            }
            .padding(.horizontal, CFSpacing.base)
            .padding(.vertical, 12)
        }
    }

    private func iconBadge(_ icon: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.15))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            )
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
