//
//  CustomerReturnLabelStep.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

/// The customer's postage label CTA: request, then track and download.
///
/// Twin of `LabelStep` in `src/components/customer/SellNextStepsCard.tsx` -
/// same three states (no label yet / label ready / expired), same copy where
/// it says the same thing. Mounted inside `CustomerSellNextStepsCard`,
/// between the fulfilment step and the arrival step, matching the web
/// layout order.
///
/// Copy rules: UK English, hyphens only (no en dash, em dash or minus), and
/// "shop" rather than "workshop".
struct CustomerReturnLabelStep: View {
    @StateObject private var viewModel: CustomerReturnLabelViewModel

    /// The route they picked, so the pre-label prompt can state it rather than
    /// ask it. See `labelPrompt` below and its twin in `SellNextStepsCard.tsx`.
    private let fulfilment: String?

    /// Momentary "Copied" confirmation on the tracking-number button.
    @State private var copiedTracking = false

    init(ticketId: String, fulfilment: String? = nil) {
        _viewModel = StateObject(wrappedValue: CustomerReturnLabelViewModel(ticketId: ticketId))
        self.fulfilment = fulfilment
    }

    var body: some View {
        Group {
            if viewModel.checking {
                checkingView
            } else if let loadError = viewModel.loadError {
                errorView(loadError)
            } else if let label = viewModel.label, label.isExpired {
                expiredView
            } else if let label = viewModel.label {
                readyView(label)
            } else {
                requestView
            }
        }
        #if os(iOS)
        .sheet(isPresented: $viewModel.showingPdf) {
            if let url = viewModel.pdfFileURL {
                QuickLookPreview(url: url)
            }
        }
        #endif
        // *** GET must never create ***. `.task` only ever calls
        // `viewModel.load()`, which reads back a label a PREVIOUS tap already
        // created - the GET endpoint 404s to "none" rather than creating one
        // (see `CustomerEnquiryService.fetchReturnLabel`). Portal links
        // travel by email and SMS, and Gmail/Outlook link scanners and
        // browser prefetchers issue GETs on them with nobody at the keyboard
        // - a creating GET here would silently mint a real, chargeable Royal
        // Mail shipment. The only path that may create a label is the button
        // in `requestView`, via `viewModel.requestLabel()`. Never move that
        // call into this `.task`, an `.onAppear`, or `.refreshable`.
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Checking

    private var checkingView: some View {
        step(icon: "paperplane", title: "Your postage label") {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking whether you already have one...")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        step(icon: "exclamationmark.circle", title: "Your postage label") {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Expired

    /// A seller looking at this has a ticket that is still open, so it has NOT gone
    /// cold - a cold one is closed by the inactivity sweep and never renders here.
    /// It outlived Royal Mail's own ceiling instead. Reissuing costs nothing, so
    /// sending them off to email us was a dead end for someone already looking at
    /// the thing they need.
    private var expiredView: some View {
        step(icon: "clock", title: "Your postage label has expired") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Royal Mail labels only last so long. Get a fresh one now - it is free, and your offer is not affected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await viewModel.requestLabel() }
                } label: {
                    if viewModel.isRequesting {
                        Label("Getting your label...", systemImage: "paperplane")
                    } else {
                        Label("Send me a new label", systemImage: "paperplane")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRequesting)

                if let requestError = viewModel.requestError {
                    Text(requestError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Ready

    private func readyView(_ label: CustomerReturnLabel) -> some View {
        step(icon: "paperplane", title: "Your postage label is ready") {
            VStack(alignment: .leading, spacing: 8) {
                // Never invent a date or number: only shown when the API
                // actually sent an expires_at we could compute from.
                if let remaining = label.daysRemaining {
                    (
                        Text("Tracking number ")
                        + Text(label.trackingNumber).fontWeight(.bold)
                        + Text(". Valid for \(remaining) more day\(remaining == 1 ? "" : "s").")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    (
                        Text("Tracking number ")
                        + Text(label.trackingNumber).fontWeight(.bold)
                        + Text(".")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text("Print it and drop the parcel at any Post Office. Would rather not print? Book a free door collection using the tracking number above - Royal Mail will print the label and bring it with them, so you do not need a printer at all.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://www.postoffice.co.uk/branch-finder")!) {
                    Label("Find your nearest Post Office", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }

                Link(destination: URL(string: "https://send.royalmail.com/collect/youritems")!) {
                    Label("Book a free door collection", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }

                // Booking that collection means typing the tracking number into Royal
                // Mail's site, so make it one tap rather than a careful transcription.
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = label.trackingNumber
                    #elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(label.trackingNumber, forType: .string)
                    #endif
                    copiedTracking = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        copiedTracking = false
                    }
                } label: {
                    Label(
                        copiedTracking ? "Copied" : "Copy tracking number",
                        systemImage: copiedTracking ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await viewModel.downloadPdf() }
                } label: {
                    if viewModel.isDownloading {
                        Label("Opening...", systemImage: "arrow.down.doc")
                    } else {
                        Label("Download your label", systemImage: "arrow.down.doc")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDownloading)
                .padding(.top, 2)

                if let downloadError = viewModel.downloadError {
                    Text(downloadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Request

    /// How the pre-label prompt reads depends on the route they picked.
    ///
    /// For `collection` this IS their route, so it states it rather than asking.
    /// For `visit` and `doorstep` the label is a genuine alternative and is
    /// offered as one - asking "Posting it to us?" of someone who booked a
    /// doorstep pickup reads as though the form threw their answer away. Nil
    /// never chose a route, so the plain question is the honest one.
    ///
    /// Twin of `labelPrompt` in `src/components/customer/SellNextStepsCard.tsx`.
    private var labelPrompt: (title: String, body: String) {
        switch fulfilment {
        case CustomerFulfilment.collection:
            return ("We send you a postage label",
                    "Press the button below and we will email your free, pre-paid Royal Mail label with a tracking number. There is nothing to pay and nothing to arrange with us first.")
        case CustomerFulfilment.visit:
            return ("Rather not come in?",
                    "You do not have to. We can send you a free, pre-paid Royal Mail label instead, so posting it costs you nothing.")
        case CustomerFulfilment.doorstep:
            return ("Rather post it instead?",
                    "If waiting in for us does not suit, we can send you a free, pre-paid Royal Mail label instead and cancel the collection.")
        default:
            return ("Posting it to us?",
                    "We can send you a free, pre-paid Royal Mail label so posting it costs you nothing.")
        }
    }

    private var requestView: some View {
        step(icon: "paperplane", title: labelPrompt.title) {
            VStack(alignment: .leading, spacing: 8) {
                Text(labelPrompt.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // The button that can never fire twice. See
                // CustomerReturnLabelViewModel.requestLabel for the guard.
                Button {
                    Task { await viewModel.requestLabel() }
                } label: {
                    if viewModel.isRequesting {
                        Label("Requesting...", systemImage: "paperplane")
                    } else {
                        Label("Send me a postage label", systemImage: "paperplane")
                    }
                }
                .buttonStyle(.borderedProminent)
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

/// State for the customer's return-label CTA. Owns the two customer network
/// calls and the single-fire guard on the create button.
@MainActor
final class CustomerReturnLabelViewModel: ObservableObject {
    let ticketId: String

    @Published private(set) var checking = true
    @Published private(set) var label: CustomerReturnLabel?
    @Published private(set) var loadError: String?

    @Published private(set) var isRequesting = false
    @Published private(set) var requestError: String?

    @Published private(set) var isDownloading = false
    @Published private(set) var downloadError: String?
    @Published var showingPdf = false
    @Published private(set) var pdfFileURL: URL?

    init(ticketId: String) {
        self.ticketId = ticketId
    }

    /// Read-only. See the `.task` docstring on `CustomerReturnLabelStep` for
    /// why this must never be the thing that creates a label.
    func load() async {
        checking = true
        loadError = nil
        do {
            label = try await CustomerEnquiryService.fetchReturnLabel(ticketId: ticketId)
        } catch {
            loadError = "Could not check for a postage label. Please try again."
        }
        checking = false
    }

    /// Only ever called from the button in `requestView`. `isRequesting` is
    /// checked and set before the first `await` below. Because this class is
    /// `@MainActor`, Swift Concurrency guarantees no other call on this actor
    /// runs between that check and that set - so a fast double tap cannot
    /// start two requests. (The web equivalent needs a second, synchronous
    /// `useRef` guard alongside its state flag because React state updates
    /// asynchronously and a double-click can fire both handlers in the same
    /// tick before either state update lands; Swift's actor isolation already
    /// gives that same guarantee with a single flag - there is no gap for a
    /// second tap to land in.) Once this succeeds, `label` is non-nil and the
    /// view renders no create button at all - a second tap is then
    /// structurally impossible, not just discouraged.
    func requestLabel() async {
        guard !isRequesting else { return }
        isRequesting = true
        requestError = nil
        do {
            label = try await CustomerEnquiryService.requestReturnLabel(ticketId: ticketId)
        } catch APIError.rateLimited {
            requestError = "A postage label was already requested for this ticket recently. "
                + "Please check your email - we may already have sent it."
        } catch let error as APIError {
            requestError = error.localizedDescription
        } catch {
            requestError = "Failed to request the postage label"
        }
        isRequesting = false
    }

    /// Fetches the PDF bytes and opens them. iOS presents a Quick Look sheet;
    /// Mac opens the saved file in the user's default PDF viewer, since there
    /// is no in-app Quick Look sheet on macOS.
    func downloadPdf() async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadError = nil
        do {
            let data = try await CustomerEnquiryService.fetchReturnLabelPdfData(ticketId: ticketId)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("postage-label-\(ticketId)")
                .appendingPathExtension("pdf")
            try data.write(to: url, options: .atomic)
            pdfFileURL = url
            #if os(iOS)
            showingPdf = true
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        } catch {
            downloadError = "Failed to open the label. Please try again."
        }
        isDownloading = false
    }
}
