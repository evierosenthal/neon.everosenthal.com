import SwiftUI

/// `.text-input`.
struct NeonTextField: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if secure {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
                    .keyboardType(keyboard)
            }
        }
        .textContentType(contentType)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled()
        .focused($focused)
        .font(NeonFont.sans(14))
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassTile(cornerRadius: 12, fill: NeonColors.white(0.05),
                   border: focused ? NeonColors.cyan400 : NeonColors.white(0.1))
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(NeonColors.slate500).font(NeonFont.sans(14))
    }
}

/// `.auth-error`: a rose message line (hidden when empty).
struct FormError: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(NeonFont.sans(12, .semibold))
                .foregroundStyle(NeonColors.rose400)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

/// `.auth-success`: an emerald message line.
struct FormNotice: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(NeonFont.sans(12, .semibold))
                .foregroundStyle(NeonColors.emerald400)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

/// `.settings-label`: a section heading, optionally with a cyan readout on the right.
struct SettingsLabel: View {
    let title: String
    var value: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(NeonFont.sans(12, .bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(NeonColors.slate300)
            Spacer()
            if let value {
                Text(value)
                    .font(NeonFont.display(12))
                    .foregroundStyle(NeonColors.cyan400)
                    .neonGlow(NeonColors.cyan400.opacity(0.4))
            }
        }
    }
}

/// `.speed-slider`: a gradient track with a glowing thumb. Custom-drawn so
/// it matches the web; adjustable through VoiceOver.
struct NeonSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var label = ""
    var onEditingChanged: ((Bool) -> Void)? = nil

    private let thumbSize: CGFloat = 20
    private let trackHeight: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width - thumbSize)
            let span = Double(range.upperBound - range.lowerBound)
            let fraction = span > 0 ? Double(value - range.lowerBound) / span : 0
            let x = CGFloat(fraction) * width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [NeonColors.indigo600, NeonColors.cyan500],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(NeonColors.white(0.15), lineWidth: 1))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)
                Circle()
                    .fill(RadialGradient(colors: [Color(css: "#e0f2fe"), NeonColors.cyan400, NeonColors.cyan500],
                                         center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: thumbSize * 0.65))
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: NeonColors.cyan400.opacity(0.7), radius: 5)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: x)
            }
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = max(0, min(1, (g.location.x - thumbSize / 2) / width))
                        let v = range.lowerBound + Int((Double(f) * span).rounded())
                        if v != value { value = v }
                        onEditingChanged?(true)
                    }
                    .onEnded { _ in onEditingChanged?(false) }
            )
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            let step = max(1, (range.upperBound - range.lowerBound) / 20)
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }
}

/// `.speed-row`: SLOW ---- FAST.
struct SliderRow: View {
    let leading: String
    let trailing: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var label = ""

    var body: some View {
        HStack(spacing: 12) {
            end(leading)
            NeonSlider(value: $value, range: range, label: label)
            end(trailing)
        }
    }

    private func end(_ text: String) -> some View {
        Text(text)
            .font(NeonFont.sans(10, .bold))
            .tracking(1)
            .foregroundStyle(NeonColors.slate500)
            .fixedSize()
    }
}
