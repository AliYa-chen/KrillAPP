#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import Krill

final class RefreshControlLayoutTests: XCTestCase {
    @MainActor
    func testRefreshLabelKeepsItsSizeWhileLoading() {
        for loading in [false, true] {
            let controller = UIHostingController(rootView: RefreshControlLabel(isRefreshing: loading))
            let size = controller.sizeThatFits(in: CGSize(width: 1000, height: 1000))
            XCTAssertEqual(size.width, 24, accuracy: 0.5)
            XCTAssertEqual(size.height, 24, accuracy: 0.5)
        }
    }

    @MainActor
    func testRefreshButtonDoesNotExpandInsideNativeToolbar() async throws {
        let state = LoadingState()
        let controller = UIHostingController(rootView: ToolbarFixture(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        for loading in [false, true, false] {
            state.loading = loading
            try await Task.sleep(for: .milliseconds(150))
            controller.view.layoutIfNeeded()
            let indicators = descendants(of: controller.view).compactMap { $0 as? UIActivityIndicatorView }
            XCTAssertFalse(indicators.isEmpty)
            for indicator in indicators {
                XCTAssertLessThanOrEqual(indicator.bounds.width, 44)
                XCTAssertLessThanOrEqual(indicator.bounds.height, 44)
            }
        }
    }

    @MainActor private func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }
}

@MainActor @Observable private final class LoadingState {
    var loading = false
}

private struct ToolbarFixture: View {
    let state: LoadingState
    var body: some View {
        NavigationStack {
            Color.white
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {} label: {
                            RefreshControlLabel(isRefreshing: state.loading)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(state.loading)
                        .transaction { $0.animation = nil }
                    }
                }
        }
    }
}
#endif
