import SwiftUI

struct RootTabView: View {
    @StateObject private var infoViewModel = InfoViewModel()
    @StateObject private var lanViewModel = LANViewModel()
    @StateObject private var toolsViewModel = ToolsViewModel()
    @AppStorage("hasSeenPermissionsOnboarding") private var hasSeenPermissionsOnboarding = false

    var body: some View {
        TabView {
            InfoView(viewModel: infoViewModel)
                .tabItem {
                    Label("Info", systemImage: "wifi")
                }

            LANView(viewModel: lanViewModel)
                .tabItem {
                    Label("LAN", systemImage: "dot.radiowaves.left.and.right")
                }

            ToolsView(viewModel: toolsViewModel)
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
        }
        .tint(.blue)
        .fullScreenCover(isPresented: .constant(!hasSeenPermissionsOnboarding)) {
            PermissionsOnboardingView {
                hasSeenPermissionsOnboarding = true
            }
        }
    }
}
