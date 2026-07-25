//
//  CustomerPackagingStep.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import SwiftUI

/// "No box to post it in?" - the seller asks us to post them packaging.
///
/// This step records a REQUEST and nothing more. It creates no Royal Mail label
/// and bills nothing: the outbound leg is Tracked 24, charged at manifest whether
/// the parcel ships or not, so a customer press must never be able to put a real
/// parcel on the van. Staff turn the request into a label from the enquiry page.
/// Do not repoint this at a label-creating endpoint.
///
/// Copy rules for this file: UK English, hyphens only (no en dash, em dash or
/// minus), "device" rather than "phone", and "shop" rather than "workshop".
///
/// Twin of the `PackagingStep` component in
/// `src/components/customer/SellNextStepsCard.tsx` in the web portal. Change the
/// wording in one, change it in the other.
struct CustomerPackagingStep: View {

    @StateObject private var viewModel: CustomerPackagingViewModel

    init(ticketId: String) {
        _viewModel = StateObject(wrappedValue: CustomerPackagingViewModel(ticketId: ticketId))
    }

    var body: some View {
        Group {
            if viewModel.checking {
                // Nothing while we do not yet know. An empty slot beats a button
                // that flips to "already asked" a moment after they read it.
                EmptyView()
            } else if viewModel.hasAsked {
                askedView
            } else {
                requestView
            }
        }
        // Read-only. The POST that records the request lives ONLY in the button
        // action below - never here, or a link preview or prefetch would file
        // packaging requests with nobody at the keyboard.
        .task { await viewModel.load() }
    }

    // MARK: - Already asked

    private var askedView: some View {
        step(icon: "checkmark.seal", title: "Packaging is on its way") {
            Text("We have your request for packaging. We will post a jiffy bag out to you with the postage label already on it, so all you need to do is put the device inside and seal it. Allow 1 to 2 working days.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Request

    private var requestView: some View {
        step(icon: "shippingbox", title: "No box to post it in?") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ask us and we will post you a jiffy bag with the label already on it, free of charge. Allow 1 to 2 working days for it to reach you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await viewModel.requestPackaging() }
                } label: {
                    if viewModel.isRequesting {
                        Label("Asking...", systemImage: "shippingbox")
                    } else {
                        Label("Send me packaging too", systemImage: "shippingbox")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRequesting)

                if let requestError = viewModel.requestError {
                    Text(requestError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Layout

    private func step<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - View Model

/// State for the packaging CTA. Owns the two customer network calls and the
/// single-fire guard on the request button.
@MainActor
final class CustomerPackagingViewModel: ObservableObject {
    let ticketId: String

    @Published private(set) var checking = true
    @Published private(set) var hasAsked = false

    @Published private(set) var isRequesting = false
    @Published private(set) var requestError: String?

    init(ticketId: String) {
        self.ticketId = ticketId
    }

    /// Read-only. Never the thing that records a request.
    ///
    /// A failed read deliberately leaves `hasAsked` false so the button still
    /// renders: the seller can still ask, and the server keeps the first
    /// timestamp if they had already asked, so a duplicate press is harmless.
    func load() async {
        checking = true
        do {
            hasAsked = try await CustomerEnquiryService
                .fetchPackagingRequest(ticketId: ticketId)?.hasAsked ?? false
        } catch {
            hasAsked = false
        }
        checking = false
    }

    /// Only ever called from the button in `requestView`. `isRequesting` is
    /// checked and set before the first `await`, and because this class is
    /// `@MainActor` no other call on this actor can run between that check and
    /// that set - so a fast double tap cannot start two requests. Once this
    /// succeeds the view renders no button at all, which is the layer that makes
    /// a second press structurally impossible rather than merely unlikely.
    func requestPackaging() async {
        guard !isRequesting else { return }
        isRequesting = true
        requestError = nil
        do {
            hasAsked = try await CustomerEnquiryService
                .requestPackaging(ticketId: ticketId).hasAsked
        } catch let error as APIError {
            requestError = error.localizedDescription
        } catch {
            requestError = "Could not send your request. Please reply to your confirmation email instead."
        }
        isRequesting = false
    }
}
