import Foundation

/// A doorstep collection window, from the day the seller asked for through to the
/// two-hour window they agreed to.
///
/// Shared by every platform: iPhone, iPad and Mac all decode this, on both the
/// customer side (confirm or ask for another day) and the staff side (offer a
/// window). The API returns `snake_case` and the decoders use
/// `.convertFromSnakeCase`, so the property names here are the camelCase of the
/// wire names and need no CodingKeys.
///
/// `summary` is built server side so the portal, the staff ticket, the iPhone and
/// the Mac cannot drift into describing the same slot differently. Prefer it over
/// re-deriving a sentence locally.
///
/// Nothing here is a booking. No availability is tracked anywhere, so no view
/// built on this may say a slot is reserved or held.
/// Codable and Hashable rather than just Decodable: the staff `Ticket` model is
/// `Codable, Equatable, Hashable`, and a Decodable-only property would stop all
/// three synthesising.
struct CollectionSlot: Codable, Sendable, Equatable, Hashable {
    /// `requested` -> `offered` -> `confirmed`. Decoded as a String rather than an
    /// enum so a state added server side cannot fail the whole enquiry decode.
    let state: String

    /// What the seller asked for, kept even after an offer so staff can see how far
    /// the offer moved. `YYYY-MM-DD` and `morning` | `afternoon`.
    let requestedDate: String?
    let requestedWindow: String?

    /// What staff offered. `YYYY-MM-DD` and `HH:MM` 24-hour. The end is sent rather
    /// than derived, so changing the window length later cannot rewrite what a
    /// customer already agreed to.
    let offeredDate: String?
    let offeredStart: String?
    let offeredEnd: String?

    /// `staff` | `customer`, and when. Says whose turn it is without re-deriving it.
    let updatedBy: String?
    let updatedAt: String?

    /// The one sentence every surface shows. Phrased for staff.
    let summary: String?

    var isRequested: Bool { state == "requested" }
    var isOffered: Bool { state == "offered" }
    var isConfirmed: Bool { state == "confirmed" }

    /// True when the customer has something to act on.
    var needsCustomerAnswer: Bool { isOffered }

    /// True when staff owe the customer a window.
    var needsStaffWindow: Bool { isRequested }

    /// "Thursday, 30 July" from a `YYYY-MM-DD` wire date.
    ///
    /// Parsed with an explicit UTC calendar rather than `ISO8601DateFormatter`,
    /// which wants a time component and returns nil for a bare date.
    static func displayDay(_ iso: String?) -> String? {
        guard let iso, iso.count == 10 else { return nil }
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let date = calendar.date(from: components) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }

    /// "Thursday, 30 July, 10:00 to 12:00", or nil when nothing has been offered.
    var offeredDescription: String? {
        guard let day = Self.displayDay(offeredDate),
              let start = offeredStart, let end = offeredEnd else { return nil }
        return "\(day), \(start) to \(end)"
    }

    /// "Thursday, 30 July, morning", or nil when no day was asked for.
    var requestedDescription: String? {
        guard let day = Self.displayDay(requestedDate) else { return nil }
        guard let window = requestedWindow else { return day }
        return "\(day), \(window)"
    }
}

/// `POST /api/customer/enquiries/:id/collection-slot/request`
///
/// Encodable rather than a dictionary so a mistyped key is a compile error. Both
/// keys are already single words, so `.convertToSnakeCase` leaves them alone.
struct CollectionSlotRequestBody: Encodable, Sendable {
    let date: String
    let window: String
}

/// `POST /api/tickets/:id/collection-slot/offer`
///
/// `startTime` reaches the API as `start_time`: APIClient encodes with
/// `.convertToSnakeCase`, so writing the key by hand here would send
/// `start_time` twice over or, worse, `starttime`.
struct CollectionSlotOfferBody: Encodable, Sendable {
    let date: String
    let startTime: String
}

/// What all three slot endpoints return.
struct CollectionSlotResponse: Decodable, Sendable {
    let collectionSlot: CollectionSlot?
}
