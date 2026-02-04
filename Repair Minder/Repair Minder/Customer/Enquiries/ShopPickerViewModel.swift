//
//  ShopPickerViewModel.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// View model for shop picker
@MainActor
@Observable
final class ShopPickerViewModel {
    private(set) var previousShops: [Shop] = []
    private(set) var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "ShopPicker")

    /// Load previous shops from API
    func loadPreviousShops() async {
        isLoading = true
        error = nil

        do {
            let response: ShopsResponse = try await APIClient.shared.request(
                .customerShops(),
                responseType: ShopsResponse.self
            )
            previousShops = response.shops
            logger.debug("Loaded \(self.previousShops.count) previous shops")
        } catch let apiError as APIError {
            logger.error("Failed to load shops: \(apiError.localizedDescription)")
            switch apiError {
            case .offline:
                error = "You're offline. Please try again when connected."
            default:
                error = "Failed to load shops."
            }
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred."
        }

        isLoading = false
    }
}

struct ShopsResponse: Codable {
    let shops: [Shop]
}
