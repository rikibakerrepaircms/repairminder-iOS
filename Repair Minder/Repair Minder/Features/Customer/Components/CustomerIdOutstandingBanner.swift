//
//  CustomerIdOutstandingBanner.swift
//  Repair Minder
//
//  "You have accepted - now we need your ID", as the loudest thing on the order.
//
//  WHEN THIS OUTRANKS THE OFFER. Before acceptance the offer and its Accept button are
//  what the screen is for. The moment the seller accepts, that reverses: the offer is
//  dealt with and this is the only thing between them and their money. Riki: "when the
//  offer is accepted but no id is provided the uploading of id should be the most
//  prominent cta".
//
//  It renders only in that exact window - accepted, nothing uploaded, no passing check -
//  which the Worker collapses into `seller_id_outstanding`. Once anything arrives that
//  goes false and the banner disappears on the next fetch.
//
//  DOCUMENTS GO THROUGH THE APP, NOT BY EMAIL. An identity document sent as an
//  attachment sits on mail servers and in sent folders; uploaded here it goes into R2
//  behind a staff-only route. The seller cannot retrieve it afterwards, from this app or
//  anywhere else - the Worker stores it against a ticket note, and every customer
//  endpoint filters notes out.
//
//  Web twin: src/components/customer/IdOutstandingBanner.tsx.
//

import SwiftUI
import PhotosUI

struct CustomerIdOutstandingBanner: View {

    @ObservedObject var viewModel: CustomerOrderDetailViewModel

    @State private var pickedItem: PhotosPickerItem?

    private let sourceURL = URL(string: "https://www.gov.uk/guidance/vat-tertiary-legislation/margin-schemes")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("One thing left: we need to see your ID", systemImage: "person.text.rectangle")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Your offer is accepted. We cannot pay you until we have checked your name and address against photo ID - HMRC requires it on every second-hand purchase from a private seller.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Photo or PDF, up to 5MB. Add your proof of address too, unless your ID already shows it.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // PhotosPicker rather than a document picker: the overwhelming case is a
            // phone photo of a licence, and it works on iOS, iPad and Mac alike.
            PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    if viewModel.uploadingIdDocument {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(viewModel.uploadingIdDocument ? "Sending..." : "Send us your ID")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.uploadingIdDocument)
            .accessibilityIdentifier("customer-id-upload-button")

            if viewModel.idDocumentSent && !viewModel.uploadingIdDocument {
                Label("Got it. Add another if you need to.", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            if let error = viewModel.idDocumentError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("Rather show us in person? Bring it into the shop and we keep no copy.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Link("Why we have to", destination: sourceURL)
                .font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                // loadTransferable gives the ORIGINAL bytes. Re-encoding through UIImage
                // would strip the file type the endpoint validates on and quietly
                // recompress the very details we are asking the seller to make legible.
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    viewModel.idDocumentError = "Could not read that image. Please try another."
                    return
                }
                let name = item.supportedContentTypes.first?.preferredFilenameExtension
                    .map { "id-document.\($0)" } ?? "id-document.jpg"
                let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                await viewModel.uploadIdDocument(data: data, fileName: name, mimeType: mime)
                // Clear the selection so picking the SAME image again still fires.
                pickedItem = nil
            }
        }
    }
}
