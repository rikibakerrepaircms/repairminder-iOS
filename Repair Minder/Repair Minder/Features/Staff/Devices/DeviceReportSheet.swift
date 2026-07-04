//
//  DeviceReportSheet.swift
//  Repair Minder
//

import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

/// Fetches the server-rendered, print-ready device report HTML
/// (`GET /api/orders/:orderId/devices/:deviceId/report`) and displays it in a
/// `WKWebView`, mirroring `DocumentPreviewSheet`'s browser-print-to-PDF UX
/// (toolbar Print + Share). The M360 quote-report variant is intentionally
/// out of scope for v1.
struct DeviceReportSheet: View {
    let orderId: String
    let deviceId: String
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DeviceDetailViewModel

    @State private var htmlString: String?
    @State private var isLoading = true
    @State private var isWebViewReady = false
    @State private var loadError: String?
    @State private var webView: WKWebView?

    init(orderId: String, deviceId: String) {
        self.orderId = orderId
        self.deviceId = deviceId
        _viewModel = State(initialValue: DeviceDetailViewModel(orderId: orderId, deviceId: deviceId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let html = htmlString {
                    DeviceReportWebViewRepresentable(
                        htmlString: html,
                        webView: $webView,
                        isReady: $isWebViewReady
                    )
                    .opacity(isWebViewReady ? 1 : 0)
                }

                if isLoading || (htmlString != nil && !isWebViewReady) {
                    ProgressView("Loading device report...")
                } else if let loadError {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("Retry") {
                            Task { await loadReport() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Device report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    #if os(iOS)
                    Button {
                        printReport()
                    } label: {
                        Image(systemName: "printer")
                    }
                    .disabled(webView == nil || !isWebViewReady)
                    #endif

                    Button {
                        shareReport()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(webView == nil || !isWebViewReady)
                    .accessibilityIdentifier("device-report-share")
                }
            }
        }
        .task {
            await loadReport()
        }
    }

    private func loadReport() async {
        isLoading = true
        loadError = nil
        isWebViewReady = false

        if let html = await viewModel.fetchDeviceReportHTML() {
            htmlString = html
        } else {
            loadError = viewModel.error ?? "Failed to load device report"
        }

        isLoading = false
    }

    #if os(iOS)
    private func printReport() {
        guard let webView else { return }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = "device_report_\(deviceId)"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()
        printController.present(animated: true)
    }
    #endif

    private func shareReport() {
        guard let webView else { return }

        let fileName = "device_report_\(deviceId).pdf"

        webView.createPDF { result in
            switch result {
            case .success(let pdfData):
                DispatchQueue.main.async {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    try? pdfData.write(to: tempURL)

                    #if os(iOS)
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
                    #elseif os(macOS)
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = fileName
                    savePanel.allowedContentTypes = [.pdf]
                    savePanel.begin { response in
                        if response == .OK, let url = savePanel.url {
                            try? pdfData.write(to: url)
                        }
                    }
                    #endif
                }
            case .failure:
                break
            }
        }
    }
}

// MARK: - WKWebView Representable

#if os(iOS)
private struct DeviceReportWebViewRepresentable: UIViewRepresentable {
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
        let parent: DeviceReportWebViewRepresentable

        init(parent: DeviceReportWebViewRepresentable) {
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
#elseif os(macOS)
private struct DeviceReportWebViewRepresentable: NSViewRepresentable {
    let htmlString: String
    @Binding var webView: WKWebView?
    @Binding var isReady: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.loadHTMLString(htmlString, baseURL: nil)
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: DeviceReportWebViewRepresentable

        init(parent: DeviceReportWebViewRepresentable) {
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
#endif
