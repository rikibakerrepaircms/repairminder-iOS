//
//  CustomerEnquiryService.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import Foundation

/// Customer-portal enquiry API.
///
/// Backs the customer-facing enquiry screens on iPhone, iPad and Mac. Not to be
/// confused with `Features/Staff/Enquiries`, which is the STAFF ticket queue on
/// `/api/tickets` behind staff auth and RBAC. These endpoints use the customer
/// JWT and only ever return the signed-in client's own tickets.
@MainActor
struct CustomerEnquiryService {

    private static let baseURL = "https://api.repairminder.com"

    private static let customerAuth = CustomerAuthManager.shared

    // MARK: - Requests

    /// `GET /api/customer/enquiries` — the signed-in customer's own enquiries.
    static func fetchEnquiries() async throws -> [CustomerEnquirySummary] {
        let response: APIResponse<[CustomerEnquirySummary]> = try await get("/api/customer/enquiries")
        guard response.success else {
            throw APIError.serverError(message: response.error ?? "Failed to load enquiries", code: nil)
        }
        return response.data ?? []
    }

    /// `GET /api/customer/enquiries/:ticketId` — one enquiry with its message thread.
    static func fetchEnquiry(ticketId: String) async throws -> CustomerEnquiryDetail {
        let response: APIResponse<CustomerEnquiryDetail> = try await get("/api/customer/enquiries/\(ticketId)")
        guard response.success, let detail = response.data else {
            throw APIError.serverError(message: response.error ?? "Failed to load enquiry", code: nil)
        }
        return detail
    }

    /// `POST /api/customer/enquiries/:ticketId/reply` — send a message on the thread.
    static func sendReply(ticketId: String, message: String) async throws {
        guard let token = customerAuth.accessToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)/api/customer/enquiries/\(ticketId)/reply")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["message": message])

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(APIResponse<CustomerReplyResponse>.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Failed to send message", code: nil)
        }
    }

    // MARK: - Collection slot

    /// `POST /api/customer/enquiries/:ticketId/collection-slot/confirm`
    ///
    /// Returns the slot the server actually wrote, so the caller renders from that
    /// rather than assuming the transition took.
    static func confirmCollectionSlot(ticketId: String) async throws -> CollectionSlot? {
        try await postSlot(path: "/api/customer/enquiries/\(ticketId)/collection-slot/confirm", body: [:])
    }

    /// `POST /api/customer/enquiries/:ticketId/collection-slot/request`
    ///
    /// Asking for a different day is allowed at any point, including after
    /// confirming: plans change, and the alternative is a phone call.
    static func requestCollectionSlot(
        ticketId: String, date: String, window: String
    ) async throws -> CollectionSlot? {
        try await postSlot(
            path: "/api/customer/enquiries/\(ticketId)/collection-slot/request",
            body: ["date": date, "window": window])
    }

    private static func postSlot(path: String, body: [String: Any]) async throws -> CollectionSlot? {
        guard let token = customerAuth.accessToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(APIResponse<CollectionSlotResponse>.self, from: data)
        guard apiResponse.success else {
            throw APIError.serverError(
                message: apiResponse.error ?? "Could not update the collection time", code: nil)
        }
        return apiResponse.data?.collectionSlot
    }

    // MARK: - Return label

    /// `GET /api/customer/enquiries/:ticketId/return-label`
    ///
    /// *** GET must never create ***. The portal link this backs travels by
    /// email and SMS, and link scanners/prefetchers in Mail and Messages
    /// issue GETs on it with nobody at the keyboard. If a GET could create a
    /// label it would silently mint a real, chargeable Royal Mail shipment.
    /// This call is a pure read: the endpoint 404s when no label exists yet,
    /// which is not an error here, just "none yet". Safe to call on view
    /// appear and on pull-to-refresh. The ONLY call that may create a label
    /// is `requestReturnLabel` below, and only from a button action.
    static func fetchReturnLabel(ticketId: String) async throws -> CustomerReturnLabel? {
        do {
            let response: APIResponse<CustomerReturnLabel> =
                try await get("/api/customer/enquiries/\(ticketId)/return-label")
            return response.success ? response.data : nil
        } catch APIError.notFound {
            return nil
        }
    }

    /// `POST /api/customer/enquiries/:ticketId/return-label`
    ///
    /// Idempotent server-side (a second call returns the same row and makes
    /// no Royal Mail request) and rate limited 5/hour per ticket - but this
    /// client must not lean on either safety net. Call this ONLY from a
    /// button's action, guarded so a fast double-tap cannot start two
    /// requests (see `CustomerReturnLabelViewModel.requestLabel` in
    /// `CustomerReturnLabelStep.swift`). Never call this from `.task`,
    /// `.onAppear`, or `refreshable`.
    ///
    /// `address` is optional and only ever needed by a repair walk-in: the
    /// storefront never asked them for one (a repair only needs an address
    /// where we are actually collecting, unlike a buyback, which always
    /// records the seller's), so the server can 422 with
    /// `code: "ADDRESS_REQUIRED"` - surfaced here as
    /// `APIError.serverError(_, code: "ADDRESS_REQUIRED")`, which
    /// `CustomerReturnLabelViewModel.requestLabel` matches on to show the
    /// address form. Passing `address` retries with it in the body so the
    /// server can write it, on a COALESCE guard that never overwrites an
    /// address the client already has, before minting.
    static func requestReturnLabel(
        ticketId: String, address: CustomerReturnLabelAddress? = nil
    ) async throws -> CustomerReturnLabel {
        guard let token = customerAuth.accessToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)/api/customer/enquiries/\(ticketId)/return-label")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(address ?? CustomerReturnLabelAddress())

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(APIResponse<CustomerReturnLabel>.self, from: data)
        guard apiResponse.success, let label = apiResponse.data else {
            throw APIError.serverError(
                message: apiResponse.error ?? "Failed to request the postage label",
                code: apiResponse.code)
        }
        return label
    }

    /// `GET /api/customer/enquiries/:ticketId/return-label?format=pdf` - the
    /// stored label as raw PDF bytes. Read-only, same "GET never creates"
    /// contract as `fetchReturnLabel` above.
    static func fetchReturnLabelPdfData(ticketId: String) async throws -> Data {
        guard let token = customerAuth.accessToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)/api/customer/enquiries/\(ticketId)/return-label?format=pdf")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)
        return data
    }

    // MARK: - Packaging request

    /// `GET /api/customer/enquiries/:ticketId/packaging-request`
    ///
    /// Read-only. Safe on view appear and pull-to-refresh.
    static func fetchPackagingRequest(ticketId: String) async throws -> PackagingRequest? {
        do {
            let response: APIResponse<PackagingRequest> =
                try await get("/api/customer/enquiries/\(ticketId)/packaging-request")
            return response.success ? response.data : nil
        } catch APIError.notFound {
            return nil
        }
    }

    /// `POST /api/customer/enquiries/:ticketId/packaging-request`
    ///
    /// Records the customer's ask for packaging. This creates NO Royal Mail
    /// label and bills nothing: the outbound leg is Tracked 24, charged at
    /// manifest whether the parcel ships or not, so staff decide whether to
    /// send anything. Do not repoint this at a label-creating endpoint.
    ///
    /// Idempotent server-side (pressing again keeps the first timestamp), but
    /// call it ONLY from a button action - never from `.task` or `.onAppear`.
    static func requestPackaging(ticketId: String) async throws -> PackagingRequest {
        guard let token = customerAuth.accessToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)/api/customer/enquiries/\(ticketId)/packaging-request")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(APIResponse<PackagingRequest>.self, from: data)
        guard apiResponse.success, let result = apiResponse.data else {
            throw APIError.serverError(
                message: apiResponse.error ?? "Failed to ask for packaging", code: nil)
        }
        return result
    }

    // MARK: - Transport

    private static func get<T: Decodable>(_ path: String) async throws -> APIResponse<T> {
        guard let token = customerAuth.accessToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)

        let decoder = JSONDecoder()
        // The API is snake_case throughout. Dates are parsed by hand in the models
        // because D1 returns "yyyy-MM-dd HH:mm:ss" rather than ISO8601.
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(APIResponse<T>.self, from: data)
    }

    private static func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode == 404 { throw APIError.notFound }
        if http.statusCode == 429 { throw APIError.rateLimited }
    }
}
