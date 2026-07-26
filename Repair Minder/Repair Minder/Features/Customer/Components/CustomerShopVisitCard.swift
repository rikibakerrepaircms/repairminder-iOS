//
//  CustomerShopVisitCard.swift
//  Repair Minder
//
//  Created on 26/07/2026.
//

import SwiftUI

/// Where we are, when we are open, and how to get here.
///
/// Twin of `ShopVisitCard.tsx` in the web portal: same states, same wording, same
/// order. Change one, change the other.
///
/// SHOWN ON EVERY SELL ROUTE - visit, collection (POSTAL) and doorstep alike.
///
/// It was gated on `fulfilment == "visit"` when it first landed, which left the
/// apps contradicting our own email: `buildSellOrderConfirmationEmail` puts
/// `dropOffText` - address, hours and the order ID to quote at the counter - on
/// every branch, because "the address is not an alternative route though - it is
/// where we are, and a seller who finds themselves passing should not have to hunt
/// for it". The email offered both ways to everyone and the screen offered one.
///
/// The only condition now is a location on file. There are three fulfilment values,
/// not two, and nothing in this file branches on them at all - so there is no
/// `!= "visit"` here to get wrong.
///
/// VOCABULARY: the portal calls this number the "order ID". The email and the staff
/// screens still say "reference" and "Enquiry"; moving those is a wider change that
/// has to travel together.
///
/// Nothing here is invented. No address on file means no card. No `googleMapsUrl`
/// means no Google link rather than a dead one, and the two map links drop
/// independently.
///
/// NO EMBEDDED MAP, unlike the web twin. The web renders a keyless Google Maps
/// iframe against the address string; MapKit needs coordinates, and the enquiry
/// endpoint returns none. Geocoding the address at render time would add a network
/// round trip that can fail and a pin that can be wrong, to show something the
/// Directions buttons below already do properly in a real maps app. If the API ever
/// carries a latitude and longitude, add a `Map` here.
///
/// Copy rules for this file: UK English, hyphens only (no en dash, em dash or
/// minus), "device" rather than "phone", "shop" rather than "workshop".
struct CustomerShopVisitCard: View {

    /// Absent, or empty of anything worth showing, renders nothing at all.
    var location: CustomerEnquiryLocation?

    /// Quoted at the counter, matching what the confirmation email tells them.
    var ticketNumber: Int?

    var body: some View {
        if let location, hasSomethingToShow(location) {
            // A minute is the finest unit shown, so a 30s cadence keeps it honest.
            // TimelineView rather than a Timer, so it ticks only while it is on
            // screen and stops dead when the view goes away - the same choice
            // CustomerCollectionCountdown makes.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                card(location, now: context.date)
            }
        }
    }

    private func hasSomethingToShow(_ location: CustomerEnquiryLocation) -> Bool {
        !location.oneLineAddress.isEmpty
            || location.openingHours?.isEmpty == false
            || location.googleMapsUrl != nil
            || location.appleMapsUrl != nil
    }

    @ViewBuilder
    private func card(_ location: CustomerEnquiryLocation, now: Date) -> some View {
        let status = ShopHours.status(location.openingHours, now: now)
        let today = ShopHours.today(location.openingHours, now: now)

        VStack(alignment: .leading, spacing: 10) {
            // Title left, state chip right - laid out like CustomerCollectionSlotCard's
            // header. That card puts "Waiting on you" there because an offered window
            // genuinely is waiting on a tap. Nothing on a walk-in is waiting on a tap,
            // so putting that chip here would invent a pending action; the open/closed
            // state is the thing worth a glance instead.
            HStack {
                Label("Visit us", systemImage: "storefront")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let status {
                    Text(status.status)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            status.state == .open
                                ? Color.green.opacity(0.15)
                                : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(status.state == .open ? Color.green : Color.secondary)
                }
            }

            if !location.oneLineAddress.isEmpty {
                Text(location.name.map { "\($0), \(location.oneLineAddress)" } ?? location.oneLineAddress)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // The whole reason this card exists. "Closed today" on its own is nearly
            // useless - it does not answer the one question a seller has, which is
            // whether it is worth driving over. The chip above carries the state word
            // and this panel carries the countdown, rather than both saying the same
            // thing: each message stands on its own anyway.
            if let status {
                Text(status.message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(
                        status.state == .open
                            ? Color.green.opacity(0.10)
                            : Color.secondary.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }

            // Today's own row, so the closing time itself is on screen and not only
            // as a countdown. Dropped on a day we are shut - the panel above has
            // already said so, and said when we are back.
            if let today {
                Text("Today \(today.open) to \(today.close)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let hours = location.openingHours, !hours.isEmpty {
                DisclosureGroup("All opening hours") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(ShopHours.weekOrder, id: \.self) { day in
                            HStack {
                                Text(ShopHours.dayLabels[day] ?? day)
                                    .fontWeight(.medium)
                                    .frame(width: 44, alignment: .leading)
                                if let h = hours[day] ?? nil {
                                    Text("\(h.open) - \(h.close)")
                                } else {
                                    Text("Closed")
                                }
                                Spacer()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.subheadline)
            }

            // The confirmation email tells them to quote this at the counter, so
            // the app has to carry it too. "Order ID" is the portal's word for the
            // number; the email still says "reference".
            if let ticketNumber {
                Text("Quote order ID \(String(ticketNumber)) at the counter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Both map apps rather than one platform-guessed button. Apple Maps is
            // the safe default on an Apple device, but a seller who lives in Google
            // Maps should not have to copy an address across. Each drops
            // independently: googleMapsUrl is built server side from
            // google_place_id, so a company without one gets the Apple link only.
            if let apple = location.appleMapsUrl, let url = URL(string: apple) {
                Link(destination: url) {
                    Label("Directions on Apple Maps", systemImage: "map")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            if let google = location.googleMapsUrl, let url = URL(string: google) {
                Link(destination: url) {
                    Label("Directions on Google Maps", systemImage: "map")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// Is the shop open right now, and if not, when does it next open.
///
/// Twin of `shopHours.ts` in the web portal - same rules, same wording, same
/// refusals. Kept as free functions on an enum so it can be reasoned about and
/// tested without a view.
///
/// EVERYTHING IS COMPUTED IN THE SHOP'S OWN TIMEZONE. The seller's device may be in
/// any timezone - they might be abroad and still checking on a device they are
/// selling - and the shop is in one place, with hours that are wall clock THERE.
/// `Calendar` with an explicit `TimeZone` is the counterpart of the web's
/// `Intl.DateTimeFormat(..., { timeZone })`, and is DST-aware, which a fixed offset
/// would not be: London is UTC+0 in January and UTC+1 in July.
///
/// The hours themselves come from the API per company, never hard-coded. The
/// storefront's banner hard-codes Haverhill's, which it can because it serves one
/// shop; a company with different hours, or a second location, must never be told
/// Haverhill's.
///
/// BANK HOLIDAYS ARE OUT OF SCOPE, DELIBERATELY. There is no bank-holiday data in
/// the API, so this cannot know about them and does not pretend to - on a bank
/// holiday it reports the shop's ordinary hours. Do not add an invented list here;
/// add the data to the API first.
enum ShopHours {

    static let timeZoneIdentifier = "Europe/London"

    /// Indexed to match `Calendar.component(.weekday)`, which is 1-based from Sunday.
    static let weekdayKeys = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
    ]

    /// Display order, which is not weekday order.
    static let weekOrder = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    ]

    static let dayLabels = [
        "monday": "Mon", "tuesday": "Tue", "wednesday": "Wed", "thursday": "Thu",
        "friday": "Fri", "saturday": "Sat", "sunday": "Sun",
    ]

    private static let dayFull = [
        "monday": "Monday", "tuesday": "Tuesday", "wednesday": "Wednesday",
        "thursday": "Thursday", "friday": "Friday", "saturday": "Saturday",
        "sunday": "Sunday",
    ]

    enum State { case open, closed }

    /// A short status and a short message - the shape the storefront banner uses and
    /// the shape that reads well: "Open now" / "Closing in 2 hours 15 minutes".
    struct Status: Equatable {
        let state: State
        let status: String
        let message: String
    }

    /// The shop's own wall clock: which day it is there, and how far into it.
    struct Clock: Equatable {
        /// 0 = Sunday, matching `weekdayKeys`.
        let day: Int
        /// Minutes since midnight, floored.
        let minutes: Int
        /// Seconds since midnight - the resolution a minute countdown needs.
        let seconds: Int
    }

    static func clock(_ now: Date, timeZoneIdentifier identifier: String = timeZoneIdentifier) -> Clock? {
        guard let zone = TimeZone(identifier: identifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.weekday, .hour, .minute, .second], from: now)
        guard let weekday = parts.weekday, let hour = parts.hour,
              let minute = parts.minute, let second = parts.second else { return nil }
        return Clock(
            day: weekday - 1,
            minutes: hour * 60 + minute,
            seconds: hour * 3600 + minute * 60 + second
        )
    }

    /// `"09:00"` -> 540. Nil for anything that is not a wall-clock time we can trust.
    static func toMinutes(_ hhmm: String?) -> Int? {
        guard let hhmm else { return nil }
        let parts = hhmm.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2, parts[1].count == 2,
              let hours = Int(parts[0]), let minutes = Int(parts[1]),
              (0...23).contains(hours), (0...59).contains(minutes) else { return nil }
        return hours * 60 + minutes
    }

    /// `"09:00"` -> `"9AM"`, `"17:00"` -> `"5PM"`, `"10:30"` -> `"10:30AM"`.
    ///
    /// The storefront's phrasing, which is what customers have already seen on every
    /// page of mendmyi.com. Built by hand rather than with a DateFormatter because a
    /// formatter would localise it, and this string is deliberately the same in
    /// every locale - it is describing a British shop's door.
    static func formatTime(_ hhmm: String?) -> String? {
        guard let total = toMinutes(hhmm) else { return nil }
        let hour24 = total / 60
        let minute = total % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return minute == 0
            ? "\(hour12)\(suffix)"
            : "\(hour12):\(String(format: "%02d", minute))\(suffix)"
    }

    private static func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n == 1 ? "" : "s")"
    }

    /// "Closing in 2 hours 15 minutes", to the minute, with zero units dropped.
    ///
    /// Rounds DOWN, so it never tells someone they have longer than they do. Below a
    /// minute it says so in words rather than counting "0 minutes" - the same choice
    /// CustomerCollectionCountdown makes: never show a stale or meaningless number.
    static func closingPhrase(secondsRemaining: Int) -> String {
        if secondsRemaining < 60 { return "Closing in less than a minute" }
        let totalMinutes = secondsRemaining / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "Closing in \(plural(minutes, "minute"))" }
        if minutes == 0 { return "Closing in \(plural(hours, "hour"))" }
        return "Closing in \(plural(hours, "hour")) \(plural(minutes, "minute"))"
    }

    /// Today's hours AT THE SHOP - not on the reader's calendar. A seller reading
    /// this in Sydney is already into tomorrow, and showing them Tuesday's hours
    /// while Haverhill is still on Monday afternoon is the same class of mistake the
    /// status panel exists to avoid.
    static func today(
        _ hours: [String: CustomerEnquiryDayHours?]?,
        now: Date,
        timeZoneIdentifier identifier: String = timeZoneIdentifier
    ) -> CustomerEnquiryDayHours? {
        guard let hours, let clock = clock(now, timeZoneIdentifier: identifier),
              clock.day >= 0, clock.day < weekdayKeys.count,
              let today = hours[weekdayKeys[clock.day]] ?? nil,
              toMinutes(today.open) != nil, toMinutes(today.close) != nil else { return nil }
        return today
    }

    /// Open or closed, and the countdown either way.
    ///
    /// Nil - and the caller shows nothing - when there are no hours, when the clock
    /// cannot be read, or when there is no day of the week the shop opens at all. A
    /// shop with no openable day has no honest "we next open" to give, and inventing
    /// one would send someone to a door that never unlocks.
    static func status(
        _ hours: [String: CustomerEnquiryDayHours?]?,
        now: Date,
        timeZoneIdentifier identifier: String = timeZoneIdentifier
    ) -> Status? {
        guard let hours, !hours.isEmpty,
              let clock = clock(now, timeZoneIdentifier: identifier),
              clock.day >= 0, clock.day < weekdayKeys.count else { return nil }

        if let today = hours[weekdayKeys[clock.day]] ?? nil,
           let open = toMinutes(today.open), let close = toMinutes(today.close),
           // `close > open` rejects a row we cannot make sense of (an overnight or
           // reversed pair) rather than guessing what was meant. We do not trade
           // overnight.
           close > open, clock.minutes >= open, clock.minutes < close {
            return Status(
                state: .open,
                status: "Open now",
                message: closingPhrase(secondsRemaining: close * 60 - clock.seconds)
            )
        }

        // Closed. Walk forward for the next day we open, including the rest of
        // today. Eight steps, not seven: when the only open day is the one we are
        // already past, the answer is that same weekday next week.
        for ahead in 0...7 {
            let key = weekdayKeys[(clock.day + ahead) % 7]
            guard let day = hours[key] ?? nil, let open = toMinutes(day.open) else { continue }
            // Today only counts if we have not already passed the opening time.
            if ahead == 0 && open <= clock.minutes { continue }
            guard let at = formatTime(day.open) else { continue }
            let when = ahead == 0 ? "today" : ahead == 1 ? "tomorrow" : (dayFull[key] ?? key)
            return Status(state: .closed, status: "Closed", message: "Opens \(at) \(when)")
        }

        return nil
    }
}
