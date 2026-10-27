import SwiftUI
import SafariServices

struct LoginWebDestination: Identifiable {
    let id = UUID()
    let url: URL
}

/// Opens official registration and information pages in the system browser sheet.
struct OfficialWebsiteView: UIViewControllerRepresentable {
    let destination: LoginWebDestination

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: destination.url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
