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
/// same five states (no label yet / request pending staff review / request
/// declined / label ready / expired), same copy where it says the same
/// thing. Mounted inside `CustomerSellNextStepsCard`, between the fulfilment
/// step and the arrival step, matching the web layout order.
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

    /// The address form's fields, shown in place of the create button once
    /// `viewModel.needsAddress` is set. Twin of the web card's inline form in
    /// `LabelStep.tsx` - same fields, same explanatory line, same wording.
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var postcode = ""

    /// Reported up to `CustomerSellNextStepsCard`, which withholds the packaging
    /// step until posting is actually in play. Written here rather than fetched
    /// twice: this view already knows the answer, and a second GET for the same row
    /// would be a wasted request on a customer's mobile connection.
    private let hasLabel: Binding<Bool>?

    init(ticketId: String, fulfilment: String? = nil, hasLabel: Binding<Bool>? = nil) {
        _viewModel = StateObject(wrappedValue: CustomerReturnLabelViewModel(ticketId: ticketId))
        self.fulfilment = fulfilment
        self.hasLabel = hasLabel
    }

    var body: some View {
        Group {
            if viewModel.checking {
                checkingView
            } else if let loadError = viewModel.loadError {
                errorView(loadError)
            } else {
                switch viewModel.status {
                case .ready(let label) where label.isExpired:
                    expiredView
                case .ready(let label):
                    readyView(label)
                case .pending:
                    pendingView
                case .rejected:
                    rejectedView
                case .none:
                    requestView
                }
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
        // Covers both the initial load and a label the customer creates while the
        // screen is open, so the packaging step appears the moment posting becomes
        // the route they are on.
        .onChange(of: viewModel.status) { _, newStatus in
            if case .ready = newStatus {
                hasLabel?.wrappedValue = true
            } else {
                hasLabel?.wrappedValue = false
            }
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

    // MARK: - Pending

    /// A request that has been made but not yet minted - staged behind staff
    /// approval so a bot or fake storefront submission cannot get a real,
    /// billable Royal Mail label before a human looks at it. No button here:
    /// the customer has nothing left to do but wait.
    private var pendingView: some View {
        step(icon: "paperplane", title: "Your postage label") {
            // The label is PUBLISHED HERE and they print it - it is not put in the
            // post, and the email we send is a link to this screen rather than the
            // label itself. Telling someone a label is being sent leaves them
            // waiting for an envelope that was never coming. Word for word with
            // LabelStep.tsx on the web.
            Text("We're reviewing your order. Your free pre-paid label will appear here for you to print as soon as it's ready, and we'll email you the moment it does. There is nothing you need to do in the meantime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Rejected

    /// A dead end by design: staff declined to mint a label for this
    /// request, so re-showing the request button would just start the same
    /// cycle again. Points the customer at a human via the message thread
    /// rather than offering a retry.
    private var rejectedView: some View {
        step(icon: "exclamationmark.circle", title: "Your postage label") {
            Text("We're unable to send a label for this order automatically. Please message us to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

                createControls(idleLabel: "Send me a new label", loadingLabel: "Getting your label...")
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

                // PRINT THE LABEL EITHER WAY. This used to say Royal Mail bring a
                // printed label to a door collection and that no printer is needed -
                // they do not, and it is. Someone who believed it would have booked a
                // collection, answered the door with nothing to hand over, and wasted
                // the trip. Same correction as the web card.
                Text("Print the label and tape it to the parcel first - you need to do that whichever way you send it. Then either drop the parcel at a Post Office, or book a free collection and Royal Mail will come to your door for it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // THE COVER CAP, AND THE TWO WAYS OUT OF IT.
                // The label is Royal Mail Tracked, and cover in transit is £50 -
                // less than most devices we buy. The confirmation email has said
                // this since it was written; the screen where someone is actually
                // holding the parcel did not. This is the honest reason to put
                // walking in front of someone who already has a label.
                //
                // IT MUST NOT NAME WHAT THEIR DEVICE IS WORTH. The enquiry endpoint
                // returns no quoted price - only the subject string carries one, and
                // parsing a price back out of a subject line would eventually print
                // a wrong number at a customer. So the cap is stated and the
                // comparison is left to them, exactly as the email does it. Twin of
                // the block in SellNextStepsCard.tsx.
                Text("Cover in transit is £50, which is plenty for most handsets. Worth more than that? You can bring it into the shop instead, or tell us before it moves, quoting your order ID, and we will arrange a service with higher cover.")
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
    /// A postal customer's label is STAGED when the order is placed, not minted:
    /// the storefront records a pending `label_requests` row and a human approves
    /// or rejects it (see storefront_handlers.js, which stopped minting on
    /// submission after a bot order got a real billable label). So a postal
    /// customer normally lands on `pendingView` and then on "your postage label is
    /// ready", and never reads a word of this. They only get here if the mint
    /// failed after approval - Royal Mail down, or an address we could not use -
    /// so the `collection` wording below says that plainly instead of presenting a
    /// button press as the normal route.
    ///
    /// For `visit` and `doorstep` nothing is minted up front and the label IS a
    /// genuine alternative, so it is offered as one - asking "Posting it to us?"
    /// of someone who booked a doorstep pickup reads as though the form threw
    /// their answer away. Nil never chose a route, so the plain question is the
    /// honest one.
    ///
    /// Twin of `labelPrompt` in `src/components/customer/SellNextStepsCard.tsx`.
    private var labelPrompt: (title: String, body: String) {
        switch fulfilment {
        case CustomerFulfilment.collection:
            // Was "press the button and we will EMAIL your label", which was wrong
            // twice over: the label appears here in the portal rather than by
            // email, and a postal customer is not meant to be pressing anything
            // at all.
            return ("Get your postage label",
                    "Your label is usually ready and waiting here the moment you order. This one did not come through, which is on us - press below and we will get it now. It is free and there is nothing to arrange.")
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

                // The button (or address form) that can never fire twice. See
                // CustomerReturnLabelViewModel.requestLabel for the guard.
                createControls(idleLabel: "Send me a postage label", loadingLabel: "Requesting...")
            }
        }
    }

    // MARK: - Create controls (button, or the address form in its place)

    /// The create button, or - once `viewModel.needsAddress` is set - the
    /// inline address form. Shared by `expiredView` and `requestView` so the
    /// form, once shown, does not vanish depending on which button raised it.
    ///
    /// The form retries through `viewModel.requestLabel(address:)`, so it is
    /// behind the SAME `isRequesting` guard as every other create here - see
    /// that method's docstring. Twin of `createControls` in `LabelStep.tsx`.
    @ViewBuilder
    private func createControls(idleLabel: String, loadingLabel: String) -> some View {
        if viewModel.needsAddress {
            VStack(alignment: .leading, spacing: 8) {
                Text("We need an address to send this to, so please add one below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Address line 1", text: $addressLine1)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textContentType(.streetAddressLine1)
                #endif
                TextField("Address line 2 (optional)", text: $addressLine2)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textContentType(.streetAddressLine2)
                #endif
                TextField("Town or city", text: $city)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textContentType(.addressCity)
                #endif
                TextField("Postcode", text: $postcode)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textContentType(.postalCode)
                    .autocapitalization(.allCharacters)
                #endif

                Button {
                    Task {
                        await viewModel.requestLabel(address: CustomerReturnLabelAddress(
                            addressLine1: addressLine1.trimmingCharacters(in: .whitespaces),
                            addressLine2: addressLine2.trimmingCharacters(in: .whitespaces),
                            city: city.trimmingCharacters(in: .whitespaces),
                            postcode: postcode.trimmingCharacters(in: .whitespaces)))
                    }
                } label: {
                    if viewModel.isRequesting {
                        Label(loadingLabel, systemImage: "paperplane")
                    } else {
                        Label(idleLabel, systemImage: "paperplane")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isRequesting
                    || addressLine1.trimmingCharacters(in: .whitespaces).isEmpty
                    || postcode.trimmingCharacters(in: .whitespaces).isEmpty
                )

                if let requestError = viewModel.requestError {
                    Text(requestError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await viewModel.requestLabel() }
                } label: {
                    if viewModel.isRequesting {
                        Label(loadingLabel, systemImage: "paperplane")
                    } else {
                        Label(idleLabel, systemImage: "paperplane")
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
    @Published private(set) var status: ReturnLabelStatus = .none
    @Published private(set) var loadError: String?

    @Published private(set) var isRequesting = false
    @Published private(set) var requestError: String?

    /// Set when a create attempt comes back `ADDRESS_REQUIRED` - only ever a
    /// repair walk-in, who the storefront deliberately never asked for an
    /// address (see `CustomerReturnLabelAddress`'s docstring). Swaps the plain
    /// button for the inline address form in `requestView`/`expiredView`.
    @Published private(set) var needsAddress = false

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
            status = try await CustomerEnquiryService.fetchReturnLabel(ticketId: ticketId)
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
    /// second tap to land in.) Once this succeeds, `status` has moved off
    /// `.none` - to `.pending` (awaiting a staff decision), `.rejected` (a
    /// prior request on this ticket was already declined - see the
    /// `LABEL_REQUEST_REJECTED` catch below), or `.ready` (the old
    /// behaviour, a minted label) - and in every one of those cases `body`
    /// switches away from `requestView`, so no create button is rendered at
    /// all - a second tap is then structurally impossible, not just
    /// discouraged.
    /// `address` is only ever passed by the address form once a prior call has
    /// already come back `ADDRESS_REQUIRED`. The retry goes through this SAME
    /// guarded function rather than a second, unguarded path.
    func requestLabel(address: CustomerReturnLabelAddress? = nil) async {
        guard !isRequesting else { return }
        isRequesting = true
        requestError = nil
        do {
            status = try await CustomerEnquiryService.requestReturnLabel(ticketId: ticketId, address: address)
            needsAddress = false
        } catch APIError.rateLimited {
            requestError = "A postage label was already requested for this ticket recently. "
                + "Please check your email - we may already have sent it."
        } catch APIError.serverError(_, "LABEL_REQUEST_REJECTED") {
            // A prior request on this ticket was already declined - e.g. this
            // call raced a staff decision landing while the button was
            // pressed. Land on the same dead-end messaging `load()` shows
            // when it finds a rejected request, not a generic error string.
            status = .rejected
        } catch APIError.serverError(_, "ADDRESS_REQUIRED") {
            // Swap to the address form rather than a dead-end error message. A
            // seller never lands here - see CustomerSellNextStepsCard - so this
            // is always a repair walk-in the storefront never asked for one.
            needsAddress = true
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
