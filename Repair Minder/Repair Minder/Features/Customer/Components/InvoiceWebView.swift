//
//  InvoiceWebView.swift
//  Repair Minder
//
//  Created on 23/06/2026.
//

#if os(iOS)
import SwiftUI
import WebKit

/// Renders an HTML string in a WKWebView — used for the customer invoice sheet.
struct InvoiceWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
#endif
