//
//  DocumentPreviewSheet.swift
//  Repair Minder
//

import SwiftUI
import WebKit

struct DocumentPreviewSheet: View {
    let orderId: String
    let documentType: DocumentType
    @Environment(\.dismiss) private var dismiss

    @State private var htmlData: Data?
    @State private var isLoading = true
    @State private var error: String?
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
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
                } else if let data = htmlData {
                    WebViewRepresentable(htmlData: data, webView: $webView)
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
                    .disabled(webView == nil)

                    Button {
                        shareDocument()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(webView == nil)
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

        do {
            let data = try await APIClient.shared.requestRawData(
                .orderDocument(orderId: orderId, type: documentType)
            )
            htmlData = data
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func printDocument() {
        guard let webView else { return }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = "\(documentType.displayName)"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()
        printController.present(animated: true)
    }

    private func shareDocument() {
        guard let webView else { return }

        webView.createPDF { result in
            switch result {
            case .success(let pdfData):
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(
                        activityItems: [pdfData],
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
    let htmlData: Data
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .systemBackground
        DispatchQueue.main.async {
            self.webView = wv
        }
        if let htmlString = String(data: htmlData, encoding: .utf8) {
            wv.loadHTMLString(htmlString, baseURL: nil)
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
