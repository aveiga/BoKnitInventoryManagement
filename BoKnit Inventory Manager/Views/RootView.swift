import SwiftUI

struct RootView: View {
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            RootTabView()

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.35)) {
                isShowingSplash = false
            }
        }
    }
}
