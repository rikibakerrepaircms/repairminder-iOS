//
//  NewEnquiryViewModel.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// View model for submitting new enquiries
@MainActor
@Observable
final class NewEnquiryViewModel {
    private(set) var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "NewEnquiry")

    /// Submit a new enquiry
    func submitEnquiry(
        shopId: String,
        deviceType: String,
        deviceBrand: String,
        deviceModel: String,
        issue: String,
        contactMethod: String
    ) async -> Bool {
        isLoading = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .customerSubmitEnquiry(
                    shopId: shopId,
                    deviceType: deviceType,
                    deviceBrand: deviceBrand,
                    deviceModel: deviceModel,
                    issueDescription: issue,
                    preferredContact: contactMethod
                )
            )
            logger.debug("Enquiry submitted successfully")
            isLoading = false
            return true
        } catch let apiError as APIError {
            logger.error("Failed to submit enquiry: \(apiError.localizedDescription)")
            switch apiError {
            case .offline:
                error = "You're offline. Please try again when connected."
            default:
                error = "Failed to submit enquiry. Please try again."
            }
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred."
        }

        isLoading = false
        return false
    }
}
