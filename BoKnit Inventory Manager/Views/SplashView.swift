import SwiftUI
import SwiftData

struct SplashView: View {
    @Query private var inventoryItems: [InventoryItem]

    var body: some View {
        ZStack {
            BKColor.chassis.ignoresSafeArea()

            VStack(spacing: 26) {
                VStack(spacing: 26) {
                    Image("BoKnitLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)

                    VStack(spacing: 11) {
                        Text("boknit.")
                            .font(.system(size: 42, weight: .heavy))
                            .tracking(-1)
                            .foregroundStyle(BKColor.ink)

                        HStack(spacing: 9) {
                            Rectangle().fill(BKColor.line).frame(width: 22, height: 1)
                            Text("stock & sales")
                                .bkMonoLabel(size: 9)
                                .foregroundStyle(BKColor.ink2)
                            Rectangle().fill(BKColor.line).frame(width: 22, height: 1)
                        }
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 34)
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(BKColor.panel)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(BKColor.line, lineWidth: 1))
                        cornerDot(.topLeading)
                        cornerDot(.topTrailing)
                        cornerDot(.bottomLeading)
                        cornerDot(.bottomTrailing)
                    }
                )

                VStack(spacing: 11) {
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(index < 8 ? BKColor.orange : BKColor.line)
                                .frame(height: 6)
                        }
                    }
                    HStack {
                        Text("loading inventory").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                        Spacer()
                        Text("\(inventoryItems.count) skus").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func cornerDot(_ alignment: Alignment) -> some View {
        Circle()
            .fill(BKColor.line)
            .frame(width: 5, height: 5)
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

#Preview {
    SplashView()
}
