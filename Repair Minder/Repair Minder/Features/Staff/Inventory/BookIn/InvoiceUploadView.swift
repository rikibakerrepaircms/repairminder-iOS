#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/// Pick a supplier-invoice PDF/image, upload it for AI extraction, and prefill the order.
struct InvoiceUploadView: View {
    @ObservedObject var viewModel: BookInWizardViewModel
    @State private var showImporter = false
    @State private var pickedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showImporter = true } label: {
                Label(viewModel.isBusy ? "Extracting…" : "Scan invoice (PDF or photo)", systemImage: "doc.viewfinder")
            }
            .disabled(viewModel.isBusy)
            if let url = pickedURL, url.pathExtension.lowercased() == "pdf" {
                PDFPreview(url: url).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            handlePicked(url)
        }
    }

    private func handlePicked(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        pickedURL = url
        let mime = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"
        Task { await viewModel.extract(fileData: data, fileName: url.lastPathComponent, mimeType: mime) }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url: url); return view
    }
    func updateUIView(_ view: PDFView, context: Context) { view.document = PDFDocument(url: url) }
}
#endif
