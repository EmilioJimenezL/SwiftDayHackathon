import SwiftUI

// MARK: - Primary Button
struct CFPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(CFFont.heading2())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: CFSpacing.buttonHeight)
            .background(Color.cfPrimary)
            .cornerRadius(CFSpacing.pillRadius)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Secondary Button
struct CFSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(CFFont.body(15, weight: .medium))
            }
            .foregroundColor(Color.cfPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.cfSurface)
            .overlay(
                RoundedRectangle(cornerRadius: CFSpacing.pillRadius)
                    .stroke(Color.cfBorder, lineWidth: 1)
            )
            .cornerRadius(CFSpacing.pillRadius)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Capture Card
struct CaptureCard: View {
    let capture: Capture
    
    var body: some View {
        HStack(spacing: CFSpacing.base) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cfBorder.opacity(0.4))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: capture.detectedFormulas.isEmpty ? "doc.text" : "photo")
                        .font(.system(size: 22))
                        .foregroundColor(Color.cfText3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(capture.title)
                    .font(CFFont.heading2())
                    .foregroundColor(Color.cfText1)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(Color.cfText3)
                    Text(capture.timeAgoString)
                        .font(CFFont.caption())
                        .foregroundColor(Color.cfText3)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.cfText3)
        }
        .padding(CFSpacing.base)
        .background(Color.cfSurface)
        .cornerRadius(CFSpacing.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(CFFont.heading1())
                .foregroundColor(Color.cfText1)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(CFFont.body(15, weight: .medium))
                        .foregroundColor(Color.cfAccent)
                }
            }
        }
    }
}

// MARK: - Support Tool Button
struct SupportToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: CFSpacing.sm) {
                Circle()
                    .fill(Color.cfAccent.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(Color.cfAccent)
                    )
                Text(title)
                    .font(CFFont.caption(13, weight: .medium))
                    .foregroundColor(Color.cfText2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CFSpacing.base)
            .background(Color.cfSurface)
            .cornerRadius(CFSpacing.cardRadius)
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Explanation Block View
struct ExplanationBlockView: View {
    let block: ExplanationBlock
    let delay: Double
    @State private var visible = false
    
    var body: some View {
        Group {
            if block.isCoreIdea {
                coreIdeaView
            } else {
                numberedBlockView
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 16)
        .onAppear {
            withAnimation(CFAnimation.spring.delay(delay)) {
                visible = true
            }
        }
    }
    
    private var coreIdeaView: some View {
        HStack(alignment: .top, spacing: CFSpacing.base) {
            Circle()
                .fill(Color.cfAccent.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.cfAccent)
                )
            VStack(alignment: .leading, spacing: 6) {
                Text(block.title)
                    .font(CFFont.heading2())
                    .foregroundColor(Color.cfText1)
                Text(block.body)
                    .font(CFFont.body())
                    .foregroundColor(Color.cfText2)
                    .lineSpacing(4)
            }
        }
        .padding(CFSpacing.base)
        .background(Color.cfAccent.opacity(0.08))
        .cornerRadius(CFSpacing.cardRadius)
    }
    
    private var numberedBlockView: some View {
        HStack(alignment: .top, spacing: CFSpacing.base) {
            // Number indicator
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cfAccent.opacity(0.3), lineWidth: 2)
                    .frame(width: 32, height: 32)
                Text("\(block.number ?? 0)")
                    .font(CFFont.body(15, weight: .semibold))
                    .foregroundColor(Color.cfAccent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(block.title)
                    .font(CFFont.heading2())
                    .foregroundColor(Color.cfText1)
                Text(block.body)
                    .font(CFFont.body())
                    .foregroundColor(Color.cfText2)
                    .lineSpacing(4)
            }
        }
        .padding(CFSpacing.base)
        .background(Color.cfSurface)
        .cornerRadius(CFSpacing.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Help Option Row
struct HelpOptionRow: View {
    let option: HelpOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: CFSpacing.base) {
                Image(systemName: option.icon)
                    .font(.system(size: 22))
                    .foregroundColor(Color.cfPrimary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(CFFont.heading2())
                        .foregroundColor(Color.cfText1)
                    Text(option.subtitle)
                        .font(CFFont.body(14))
                        .foregroundColor(Color.cfText2)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(CFSpacing.base)
            .background(Color(hex: "#F0EEE9"))
            .cornerRadius(CFSpacing.cardRadius)
        }
        .accessibilityLabel("\(option.title): \(option.subtitle)")
    }
}

// MARK: - Loading Indicator
struct CFLoadingIndicator: View {
    let message: String
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: CFSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.cfBorder, lineWidth: 3)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 28))
                    .foregroundColor(Color.cfPrimary)
            }
            
            VStack(spacing: 8) {
                Text(message)
                    .font(CFFont.heading1(20))
                    .foregroundColor(Color.cfText1)
                    .multilineTextAlignment(.center)
                Text("Esto tarda unos momentos.\nEstamos procesando tu documento con cuidado.")
                    .font(CFFont.body())
                    .foregroundColor(Color.cfText2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.cfAccent.opacity(0.3))
                .frame(width: 120, height: 4)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cfAccent)
                        .frame(width: 60)
                }
        }
        .padding(CFSpacing.xl)
    }
}
