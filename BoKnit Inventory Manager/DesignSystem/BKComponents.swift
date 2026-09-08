import SwiftUI

/// A numbered section label, e.g. "01  PRODUCT".
struct BKSectionLabel: View {
    let index: Int
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Text(String(format: "%02d", index))
                    .foregroundStyle(BKColor.orange)
                Text(title)
                    .foregroundStyle(BKColor.ink2)
            }
            .bkMonoLabel()
            Spacer()
            if let trailing {
                Text(trailing)
                    .bkMonoLabel()
                    .foregroundStyle(BKColor.ink2)
            }
        }
    }
}

/// The brand row shown at the top of every screen: an orange dot + "boknit."
struct BKBrandRow: View {
    var trailing: String?

    var body: some View {
        HStack {
            HStack(spacing: 7) {
                Circle().fill(BKColor.orange).frame(width: 13, height: 13)
                Text("boknit.")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(BKColor.ink)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .bkMonoLabel()
                    .foregroundStyle(BKColor.ink2)
            }
        }
    }
}

/// The large screen title with a hairline rule underneath.
struct BKScreenTitleRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .bkScreenTitle()
                .foregroundStyle(BKColor.ink)
            Spacer()
            trailing
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(BKColor.line).frame(height: 1)
        }
    }
}

extension BKScreenTitleRow where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// A hard-shadowed panel surface — the base "key" look used by buttons,
/// swatches, and rows throughout.
struct BKKeySurface<Content: View>: View {
    var cornerRadius: CGFloat = 3
    var fill: Color = BKColor.panel
    var border: Color = BKColor.line
    var borderWidth: CGFloat = 1
    var shadow: Color = BKColor.line
    var shadowOffset: CGFloat = 2
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(shadow).offset(y: shadowOffset)
                    RoundedRectangle(cornerRadius: cornerRadius).fill(fill)
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(border, lineWidth: borderWidth)
                }
            )
    }
}

/// The full-width orange primary action, with hazard ticks and a white
/// icon key — used for every screen's one confirming action.
struct BKPrimaryButton: View {
    let title: String
    var systemImage: String = "checkmark"
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 3, height: 16)
                    }
                }
                .padding(.trailing, 14)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(BKColor.orange)
                    )
                    .padding(4)
            }
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.orangeShadow).offset(y: 3)
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.orange.opacity(isDisabled ? 0.4 : 1))
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

/// A neutral full-width key for a screen's repeatable action — "add to
/// purchase" — with the same proportions as `BKPrimaryButton` but without
/// claiming the orange, which stays reserved for the one confirming action.
struct BKSecondaryButton: View {
    let title: String
    var systemImage: String = "plus"
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(BKColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(BKColor.orange)
                    .padding(.trailing, 18)
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(BKColor.line).offset(y: 2)
                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
            }
        )
        .opacity(isDisabled ? 0.45 : 1)
    }
}

/// A wide dark inset readout for a money total — the same "LCD" surface as
/// `BKStepperDisplay`, with the amount right-aligned. `caption` carries a
/// warning under the label (e.g. products with no price).
struct BKTotalDisplay: View {
    let label: String
    let amount: String
    var caption: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .bkMonoLabel(size: 8)
                    .foregroundStyle(BKColor.insetLabel)
                if let caption {
                    Text(caption)
                        .bkMonoLabel(size: 8)
                        .foregroundStyle(BKColor.orange)
                }
            }
            Spacer(minLength: 8)
            Text(amount)
                .bkStatNumber(size: 26)
                .foregroundStyle(BKColor.insetInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 15)
        .frame(height: 66)
        .background(RoundedRectangle(cornerRadius: 3).fill(BKColor.inset))
    }
}

/// A square key with an SF Symbol — used for the quantity stepper's − / + .
struct BKKeyButton: View {
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isDisabled ? BKColor.ink2.opacity(0.4) : BKColor.ink)
                .frame(width: 58, height: 62)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(BKColor.line).offset(y: 2)
                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
            }
        )
    }
}

/// The dark inset "LCD" readout used by the quantity stepper.
struct BKStepperDisplay: View {
    let value: Int

    var body: some View {
        HStack(spacing: 10) {
            BKDimmedNumber(value: value, minDigits: 3, size: 34, dimColor: BKColor.insetInkDim)
            Rectangle().fill(BKColor.insetLine).frame(width: 1, height: 26)
            Text("units")
                .bkMonoLabel(size: 9)
                .foregroundStyle(BKColor.insetLabel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(RoundedRectangle(cornerRadius: 3).fill(BKColor.inset))
    }
}

/// A colour-key tile for the colour picker grid.
struct BKSwatchTile: View {
    let swatch: Color
    let label: String
    let isSelected: Bool
    let isEmpty: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(swatch).frame(width: 20, height: 20)
                Text(label)
                    .bkMonoLabel(size: 8)
                    .foregroundStyle(isSelected ? BKColor.orange : BKColor.ink2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .opacity(isEmpty ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(isSelected ? BKColor.orange : BKColor.line).offset(y: 2)
                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                RoundedRectangle(cornerRadius: 3).strokeBorder(isSelected ? BKColor.orange : BKColor.line, lineWidth: isSelected ? 2 : 1)
            }
        )
    }
}

/// A dark inset stat tile — "148 / inventory items" style readouts.
struct BKStatTile: View {
    let label: String
    let value: String
    var valueColor: Color = BKColor.insetInk

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .bkMonoLabel(size: 8)
                .foregroundStyle(BKColor.insetLabel)
            Text(value)
                .bkStatNumber()
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14)
        .frame(height: 86)
        .background(RoundedRectangle(cornerRadius: 3).fill(BKColor.inset))
    }
}

/// A compact on/off switch matching the hardware look (replaces `Toggle`).
struct BKSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(isOn ? "ON" : "OFF")
                    .bkMonoLabel(size: 9, weight: isOn ? .bold : .regular)
                    .foregroundStyle(isOn ? BKColor.orange : BKColor.ink2)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isOn ? BKColor.orange : BKColor.panel2)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(isOn ? BKColor.orange : BKColor.line, lineWidth: 1))
                        .frame(width: 42, height: 22)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isOn ? Color.white : BKColor.ink2)
                        .frame(width: 18, height: 16)
                        .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// A small mono tag — used for quick-select buyer names.
struct BKTag: View {
    let text: String

    var body: some View {
        Text(text)
            .bkMonoLabel(size: 10)
            .foregroundStyle(BKColor.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(BKColor.panel2)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(BKColor.line, lineWidth: 1))
            )
    }
}

/// A diagonal hazard stripe used above destructive sections.
struct BKHazardStripe: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let stripeSpacing: CGFloat = 16
                var x: CGFloat = -geo.size.height
                while x < geo.size.width {
                    path.move(to: CGPoint(x: x, y: geo.size.height))
                    path.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                    x += stripeSpacing
                }
            }
            .stroke(BKColor.red, lineWidth: 8)
        }
        .frame(height: 8)
        .opacity(0.55)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
