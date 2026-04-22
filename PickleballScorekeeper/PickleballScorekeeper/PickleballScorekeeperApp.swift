import SwiftUI

@main
struct PickleballScorekeeperApp: App {
    var body: some Scene {
        WindowGroup {
            WebViewWrapper()
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .background(Color.blue)
                .ignoresSafeArea()
        }
    }
}

struct WebViewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController {
        WebViewController()
    }
    func updateUIViewController(_ vc: WebViewController, context: Context) {}
}
