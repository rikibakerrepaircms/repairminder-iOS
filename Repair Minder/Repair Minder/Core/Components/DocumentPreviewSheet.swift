//
//  DocumentPreviewSheet.swift
//  Repair Minder
//

import SwiftUI
import WebKit

struct DocumentPreviewSheet: View {
    let orderId: String
    let orderNumber: Int
    let documentType: DocumentType
    @Environment(\.dismiss) private var dismiss

    @State private var htmlString: String?
    @State private var isLoading = true
    @State private var isWebViewReady = false
    @State private var error: String?
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            ZStack {
                if let html = htmlString {
                    WebViewRepresentable(
                        htmlString: html,
                        webView: $webView,
                        isReady: $isWebViewReady
                    )
                    .opacity(isWebViewReady ? 1 : 0)
                }

                if isLoading || (htmlString != nil && !isWebViewReady) {
                    ProgressView("Loading \(documentType.displayName)...")
                } else if let error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await loadDocument() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle(documentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        printDocument()
                    } label: {
                        Image(systemName: "printer")
                    }
                    .disabled(webView == nil || !isWebViewReady)

                    Button {
                        shareDocument()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(webView == nil || !isWebViewReady)
                }
            }
        }
        .task {
            await loadDocument()
        }
    }

    private func loadDocument() async {
        isLoading = true
        error = nil
        isWebViewReady = false

        do {
            let data = try await APIClient.shared.requestRawData(
                .orderDocument(orderId: orderId, type: documentType)
            )
            htmlString = String(data: data, encoding: .utf8)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func printDocument() {
        guard let webView else { return }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = "\(documentType.filePrefix)_\(orderNumber)"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()
        printController.present(animated: true)
    }

    private func shareDocument() {
        guard let webView else { return }

        let fileName = "\(documentType.filePrefix)_\(orderNumber).pdf"

        webView.createPDF { result in
            switch result {
            case .success(let pdfData):
                DispatchQueue.main.async {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    try? pdfData.write(to: tempURL)

                    let activityVC = UIActivityViewController(
                        activityItems: [tempURL],
                        applicationActivities: nil
                    )
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        var presenter = rootVC
                        while let presented = presenter.presentedViewController {
                            presenter = presented
                        }
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = presenter.view
                            popover.sourceRect = CGRect(
                                x: presenter.view.bounds.midX,
                                y: presenter.view.bounds.midY,
                                width: 0, height: 0
                            )
                        }
                        presenter.present(activityVC, animated: true)
                    }
                }
            case .failure:
                break
            }
        }
    }
}

// MARK: - WKWebView Representable

private struct WebViewRepresentable: UIViewRepresentable {
    let htmlString: String
    @Binding var webView: WKWebView?
    @Binding var isReady: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.backgroundColor = .systemBackground
        wv.navigationDelegate = context.coordinator
        wv.loadHTMLString(htmlString, baseURL: nil)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable

        init(parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.webView = webView
                self.parent.isReady = true
            }
        }
    }
}
