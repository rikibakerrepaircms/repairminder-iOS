//
//  CustomerEnquiryListViewModel.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import Foundation
import SwiftUI

/// ViewModel for the customer's own enquiry list.
@MainActor
final class CustomerEnquiryListViewModel: ObservableObject {

    @Published private(set) var enquiries: [CustomerEnquirySummary] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    /// Load the signed-in customer's enquiries.
    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            enquiries = try await CustomerEnquiryService.fetchEnquiries()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[CustomerEnquiryListVM] Error loading enquiries: \(error)")
            #endif
        } catch {
            errorMessage = "Failed to load enquiries"
            #if DEBUG
            print("[CustomerEnquiryListVM] Unexpected error: \(error)")
            #endif
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    /// Sell orders first: someone who has just agreed to sell a device has
    /// something to do, where an ordinary enquiry is just a conversation.
    var sellEnquiries: [CustomerEnquirySummary] {
        enquiries.filter { $0.isSell }
    }

    var otherEnquiries: [CustomerEnquirySummary] {
        enquiries.filter { !$0.isSell }
    }
}
