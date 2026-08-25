//
//  IdDocumentPreview.swift
//  Repair Minder
//
//  One uploaded identity document, rendered where the questions about it are asked.
//
//  WHY IT EXISTS. SellerIdCheckSheet asks whether the name and the address on a
//  seller's document match the purchase, and had no way to show the document - it
//  asked staff to type an attachment id into a text field instead. The web panel had
//  the same fault. Riki, with a seller's photo ID sitting unopened on order 100002885:
//  "i need to see the fucking upload to check the address do i not?!"
//
//  RENDERED, NEVER DOWNLOADED. Riki again: "i want to see them without downloading
//  them." So the bytes are fetched into memory and drawn here - nothing is written to
//  disk, nothing is handed to another app, and it all goes when the sheet closes. That
//  is the right handling for someone's passport or bank statement.
//
//  BOTH PLATFORMS. This sheet is used at the counter on iPad and on the Mac, and the
//  simulator build gate does not catch a macOS break - so UIImage/NSImage and
//  UIViewRepresentable/NSViewRepresentable are both spelled out rather than assumed.
//
//  Web twin: DocumentPreview in src/components/buyback/SellerIdCheckPanel.tsx.
//

import SwiftUI
import PDFKit

struct IdDocumentPreview: View {

    let attachment: IdCheckAttachment
    let service: BuybackService

    @State private var data: Data?
    @State private var failed = false

    var body: some View {
        Group {
            if failed {
                Text("That file would not open. It may have been removed from storage.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if let data {
                if attachment.isPDF {
                    PDFDocumentView(data: data)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let image = Self.image(from: data) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Decoded to neither. HEIC from an older OS is the realistic case.
                    Text("That file could not be displayed on this device.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading the document...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: attachment.id) { await load() }
    }

    private func load() async {
        guard let ticketId = attachment.ticketId else { failed = true; return }
        do {
            data = try await service.idDocumentData(ticketId: ticketId, attachmentId: attachment.id)
        } catch {
            failed = true
        }
    }

    /// Data to a SwiftUI Image, on either platform.
    private static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
        if let ui = UIImage(data: data) { return Image(uiImage: ui) }
        #elseif canImport(AppKit)
        if let ns = NSImage(data: data) { return Image(nsImage: ns) }
        #endif
        return nil
    }
}

/// A PDF drawn in place, from bytes.
///
/// `PDFDocument(data:)` rather than `(url:)` deliberately - a URL would mean writing a
/// seller's bank statement to a temporary file, which is the thing this whole view is
/// avoiding. PDFKit ships on both platforms; only the representable protocol differs.
private struct PDFDocumentView {
    let data: Data

    fileprivate func makeView() -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
}

#if os(iOS)
extension PDFDocumentView: UIViewRepresentable {
    func makeUIView(context: Context) -> PDFView { makeView() }
    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
    }
}
#elseif os(macOS)
extension PDFDocumentView: NSViewRepresentable {
    func makeNSView(context: Context) -> PDFView { makeView() }
    func updateNSView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
    }
}
#endif
