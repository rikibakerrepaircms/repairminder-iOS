// Features/Diagnostics/Report/DiagnosticReportPDF.swift
// iOS-only: renders the branded HTML report to a PDF via an off-screen WKWebView and
// presents the system share sheet. The pure HTML/model lives in DiagnosticReport.swift.
#if os(iOS)
import UIKit
import WebKit

/// Renders report HTML to a PDF file off-screen. Retains itself for the lifetime of one
/// render (WKWebView + navigation delegate must outlive the async createPDF callback).
@MainActor
final class DiagnosticReportPDFRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var fileURL: URL?
    private var completion: ((Result<URL, Error>) -> Void)?
    private static var liveRenders: Set<DiagnosticReportPDFRenderer> = []

    enum RenderError: Error { case pdfFailed }

    /// Render `html` to a PDF named `fileName` in the temporary directory.
    func render(html: String, fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion
        self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        Self.liveRenders.insert(self)

        // A4 width in points (72 dpi) so the layout matches the print width.
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842))
        wv.navigationDelegate = self
        wv.loadHTMLString(html, baseURL: nil)
        self.webView = wv
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Let layout settle before snapshotting to PDF.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            webView.createPDF { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let data):
                    if let url = self.fileURL, (try? data.write(to: url)) != nil {
                        self.finish(.success(url))
                    } else {
                        self.finish(.failure(RenderError.pdfFailed))
                    }
                case .failure(let err):
                    self.finish(.failure(err))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<URL, Error>) {
        completion?(result)
        completion = nil
        webView = nil
        Self.liveRenders.remove(self)
    }
}

/// Builds report data, renders the PDF and presents the share sheet. One entry point for the UI.
enum DiagnosticReportShare {
    /// Load a logo imageset as a base64 PNG `data:` URI, forcing the light-appearance variant
    /// (the PDF is always on a white background).
    private static func dataURI(asset name: String) -> String? {
        guard let base = UIImage(named: name) else { return nil }
        let image = base.imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light)) ?? base
        guard let png = image.pngData() else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }

    static func assets() -> DiagnosticReportAssets {
        DiagnosticReportAssets(
            repairMinderLogoDataURI: dataURI(asset: "repairminder_logo"),
            mendmyiLogoDataURI: dataURI(asset: "mendmyi_logo")
        )
    }

    /// Generate the PDF for `runner` and present a share sheet. Calls `onComplete` (main thread)
    /// with success/failure so the caller can clear any progress state.
    @MainActor
    static func presentShareSheet(for runner: DiagnosticRunner,
                                  onComplete: @escaping (Bool) -> Void) {
        let data = DiagnosticReportData.from(runner: runner,
                                             deviceName: DeviceModelName.marketingName)
        let html = DiagnosticReportHTML.render(data, assets: assets())
        let fileName = DiagnosticReportHTML.fileName(reportID: data.reportID)

        let renderer = DiagnosticReportPDFRenderer()
        renderer.render(html: html, fileName: fileName) { result in
            switch result {
            case .success(let url):
                present(url: url)
                onComplete(true)
            case .failure:
                onComplete(false)
            }
        }
    }

    /// Present a UIActivityViewController for the generated file from the top-most controller.
    @MainActor
    private static func present(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController
        else { return }

        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }
}
#endif
