//
//  CustomerEnquiryDetailViewModel.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import Foundation
import SwiftUI

/// ViewModel for one customer enquiry and its message thread.
@MainActor
final class CustomerEnquiryDetailViewModel: ObservableObject {

    @Published private(set) var enquiry: CustomerEnquiryDetail?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // Reply state
    @Published var replyText: String = ""
    @Published private(set) var isSendingReply: Bool = false
    @Published var replyError: String?

    let ticketId: String

    init(ticketId: String) {
        self.ticketId = ticketId
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            enquiry = try await CustomerEnquiryService.fetchEnquiry(ticketId: ticketId)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Error loading enquiry: \(error)")
            #endif
        } catch let decodingError as DecodingError {
            errorMessage = "Failed to read this enquiry"
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Decode error: \(decodingError)")
            #endif
        } catch {
            errorMessage = "Failed to load enquiry"
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Unexpected error: \(error)")
            #endif
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    // MARK: - Collection slot

    /// The slot shown by the view. Held separately from `enquiry` so an action can
    /// render the server's own answer without refetching the whole thread.
    @Published private(set) var slotOverride: CollectionSlot?
    @Published private(set) var isUpdatingSlot: Bool = false
    @Published var slotError: String?

    var collectionSlot: CollectionSlot? { slotOverride ?? enquiry?.collectionSlot }

    func confirmCollectionSlot() async {
        await updateSlot { try await CustomerEnquiryService.confirmCollectionSlot(ticketId: self.ticketId) }
    }

    func requestCollectionSlot(date: String, window: String) async {
        await updateSlot {
            try await CustomerEnquiryService.requestCollectionSlot(
                ticketId: self.ticketId, date: date, window: window)
        }
    }

    private func updateSlot(_ work: @escaping () async throws -> CollectionSlot?) async {
        guard !isUpdatingSlot else { return }
        isUpdatingSlot = true
        slotError = nil
        do {
            slotOverride = try await work()
        } catch let error as APIError {
            slotError = error.localizedDescription
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Slot update failed: \(error)")
            #endif
        } catch {
            slotError = "Could not update the collection time"
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Slot update failed: \(error)")
            #endif
        }
        isUpdatingSlot = false
    }

    func sendReply() async {
        let message = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSendingReply else { return }

        isSendingReply = true
        replyError = nil

        do {
            try await CustomerEnquiryService.sendReply(ticketId: ticketId, message: message)
            replyText = ""
            // Reload so the new message appears in the thread, as the web does.
            isSendingReply = false
            await load()
            return
        } catch let error as APIError {
            replyError = error.localizedDescription
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Reply error: \(error)")
            #endif
        } catch {
            replyError = "Failed to send message. Please try again."
            #if DEBUG
            print("[CustomerEnquiryDetailVM] Unexpected reply error: \(error)")
            #endif
        }

        isSendingReply = false
    }

    /// Whether to show the sell-specific next-steps card.
    var showsSellNextSteps: Bool {
        enquiry?.isSell == true
    }

    /// A closed or resolved enquiry hides the reply box, matching the web portal.
    var isClosed: Bool {
        guard let status = enquiry?.status else { return false }
        return CustomerEnquiryStatus.isClosed(status)
    }
}
