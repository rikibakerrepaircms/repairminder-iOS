//
//  CustomerEnquiryListViewModel.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// View model for customer enquiry list
@MainActor
@Observable
final class CustomerEnquiryListViewModel {
    private(set) var enquiries: [CustomerEnquiry] = []
    private(set) var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "CustomerEnquiryList")

    /// Load enquiries from API
    func loadEnquiries() async {
        isLoading = true
        error = nil

        do {
            let response: CustomerEnquiriesResponse = try await APIClient.shared.request(
                .customerEnquiries(),
                responseType: CustomerEnquiriesResponse.self
            )
            enquiries = response.enquiries
            logger.debug("Loaded \(self.enquiries.count) enquiries")
        } catch let apiError as APIError {
            logger.error("Failed to load enquiries: \(apiError.localizedDescription)")
            switch apiError {
            case .offline:
                error = "You're offline. Pull to refresh when connected."
            default:
                error = "Failed to load enquiries."
            }
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred."
        }

        isLoading = false
    }

    /// Refresh enquiries
    func refresh() async {
        await loadEnquiries()
    }
}

struct CustomerEnquiriesResponse: Codable {
    let enquiries: [CustomerEnquiry]
}
