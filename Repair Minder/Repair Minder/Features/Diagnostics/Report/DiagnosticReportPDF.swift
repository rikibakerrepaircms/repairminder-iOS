// Features/Diagnostics/Report/DiagnosticReportPDF.swift
// iOS-only: renders the branded HTML report to a PDF via an off-screen WKWebView and
// presents the system share sheet. The pure HTML/model lives in DiagnosticReport.swift.
#if os(iOS)
import UIKit
import WebKit
import QuickLook

/// Renders report HTML to a PDF file off-screen. Retains itself for the lifetime of one
/// render (WKWebView + navigation delegate must outlive the async createPDF callback).
@MainActor
final class DiagnosticReportPDFRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var fileURL: URL?
    private var completion: ((Result<URL, Error>) -> Void)?
    private var finished = false
    private static var liveRenders: Set<DiagnosticReportPDFRenderer> = []

    enum RenderError: Error { case pdfFailed, timedOut }

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

        // Watchdog: if WebKit never reports finish/fail (rare, but it would otherwise leave the
        // caller's "generating" spinner stuck forever), fail gracefully. `finish` is idempotent.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.finish(.failure(RenderError.timedOut))
        }
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
        guard !finished else { return }   // idempotent: first of finish/fail/timeout wins
        finished = true
        completion?(result)
        completion = nil
        webView = nil
        Self.liveRenders.remove(self)
    }
}

/// Fetches the server-rendered report HTML and renders/presents the PDF. One entry point for the
/// UI. SINGLE SOURCE OF TRUTH: the Worker's `GET /api/diagnostics/session/:id/report` HTML is the
/// only report source — there is no local HTML fallback (online-only). Callers must have a real
/// server session first (`DiagnosticRunner.ensureSession()` — anonymous when the device was never
/// paired to a shop) since the report is fetched by session id + token.
enum DiagnosticReportShare {
    /// Fetch the server HTML for `sessionId`/`token`, render it to a PDF named for `reportID`, and
    /// call `completion` (main thread) with the file URL. SINGLE SOURCE OF TRUTH for generating
    /// the report — both Share (top-right arrow) and Preview (the "Generate PDF" row) go through
    /// this, so the render pipeline changes in one place.
    @MainActor
    static func generatePDF(forSession sessionId: String, token: String, reportID: String,
                            service: DiagnosticsAPI,
                            completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let html = try await service.fetchReport(sessionId: sessionId, token: token)
                let fileName = DiagnosticReportHTML.fileName(reportID: reportID)
                await MainActor.run {
                    let renderer = DiagnosticReportPDFRenderer()
                    renderer.render(html: html, fileName: fileName, completion: completion)
                }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    /// Generate the PDF and present the system share sheet (the top-right arrow). Calls `onComplete`
    /// (main thread) so the caller can clear any progress state.
    @MainActor
    static func presentShareSheet(sessionId: String, token: String, reportID: String,
                                  service: DiagnosticsAPI,
                                  onComplete: @escaping (Bool) -> Void) {
        generatePDF(forSession: sessionId, token: token, reportID: reportID, service: service) { result in
            switch result {
            case .success(let url): present(url: url); onComplete(true)
            case .failure:          onComplete(false)
            }
        }
    }

    /// Generate the SAME PDF and preview it on-device via Quick Look (the "Generate PDF" row).
    /// Quick Look includes its own Share/Print, so the user can still send from the preview.
    @MainActor
    static func presentPreview(sessionId: String, token: String, reportID: String,
                               service: DiagnosticsAPI,
                               onComplete: @escaping (Bool) -> Void) {
        generatePDF(forSession: sessionId, token: token, reportID: reportID, service: service) { result in
            switch result {
            case .success(let url): presentQuickLook(url: url); onComplete(true)
            case .failure:          onComplete(false)
            }
        }
    }

    /// Top-most presented view controller in the active window scene.
    @MainActor
    private static func topPresenter() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let scene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController
        else { return nil }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        return presenter
    }

    /// Present a UIActivityViewController for the generated file from the top-most controller.
    @MainActor
    private static func present(url: URL) {
        guard let presenter = topPresenter() else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    /// Present the PDF in a Quick Look preview from the top-most controller.
    @MainActor
    private static func presentQuickLook(url: URL) {
        guard let presenter = topPresenter() else { return }
        let source = PDFPreviewSource(url: url)
        let controller = QLPreviewController()
        controller.dataSource = source
        controller.delegate = source
        presenter.present(controller, animated: true)
    }
}

/// Retained data source/delegate for a Quick Look PDF preview. `QLPreviewController.dataSource` is
/// weak, so the source must outlive the controller; it self-retains until the preview dismisses.
@MainActor
private final class PDFPreviewSource: NSObject, QLPreviewControllerDataSource, @preconcurrency QLPreviewControllerDelegate {
    private let url: URL
    private static var live: Set<PDFPreviewSource> = []

    init(url: URL) {
        self.url = url
        super.init()
        Self.live.insert(self)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url as NSURL
    }
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        Self.live.remove(self)
    }
}
#endif
