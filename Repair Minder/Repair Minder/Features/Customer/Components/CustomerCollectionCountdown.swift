//
//  CustomerCollectionCountdown.swift
//  Repair Minder
//
//  Created on 26/07/2026.
//

import SwiftUI

/// How long until we turn up, on a collection the seller has agreed.
///
/// Twin of `CollectionCountdown.tsx` in the web portal - same three states, same
/// wording. Only ever rendered for a CONFIRMED slot: an offered one is not a promise
/// yet, and counting down to a time nobody has accepted would invent a commitment.
///
/// Uses `TimelineView` rather than a `Timer`, so it ticks only while it is on screen
/// and stops dead when the view goes away - no retained timer running behind a
/// backgrounded app.
///
/// Copy rules: UK English, hyphens only (no en dash, em dash or minus).
struct CustomerCollectionCountdown: View {

    let date: String?
    let start: String?
    let end: String?

    /// `"2026-07-31"` + `"09:00"` as a LOCAL date.
    ///
    /// These two columns are wall clock at the shop and carry no zone, so they are
    /// read in the reader's own calendar - which is right for a customer standing in
    /// the same country as the van. Built from DateComponents rather than a
    /// DateFormatter so there is no format string to get subtly wrong, and no
    /// dependence on the device locale.
    static func parseSlotStart(_ day: String?, _ time: String?) -> Date? {
        guard let day, let time else { return nil }
        let dayParts = day.split(separator: "-")
        let timeParts = time.split(separator: ":")
        guard dayParts.count == 3, timeParts.count == 2,
              let y = Int(dayParts[0]), let m = Int(dayParts[1]), let d = Int(dayParts[2]),
              let hh = Int(timeParts[0]), let mm = Int(timeParts[1]) else { return nil }
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = hh; c.minute = mm
        return Calendar.current.date(from: c)
    }

    /// Whole days, hours and minutes. Never negative - see the web twin.
    static func splitRemaining(_ seconds: TimeInterval) -> (days: Int, hours: Int, minutes: Int) {
        let totalMinutes = Int(max(0, seconds) / 60)
        return (totalMinutes / 1440, (totalMinutes % 1440) / 60, totalMinutes % 60)
    }

    private static func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n == 1 ? "" : "s")"
    }

    var body: some View {
        if let startsAt = Self.parseSlotStart(date, start) {
            // A minute is the finest unit shown, so a per-minute schedule is enough.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(startsAt: startsAt, now: context.date)
            }
        }
    }

    @ViewBuilder
    private func content(startsAt: Date, now: Date) -> some View {
        let endsAt = Self.parseSlotStart(date, end)

        if let endsAt, now > endsAt {
            // Past the window: say nothing rather than count up or freeze on zero.
            // The card's own line still states the agreed time.
            EmptyView()
        } else if now >= startsAt {
            panel {
                Text("We are due with you now")
                    .font(.headline)
                Text("Your window is open\(end.map { " until \($0)" } ?? ""). Please have the device to hand.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else {
            let r = Self.splitRemaining(startsAt.timeIntervalSince(now))
            panel {
                Text("WE COLLECT IN")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                // Only the units actually left - a leading "0 days" is noise.
                HStack(alignment: .bottom, spacing: 20) {
                    if r.days > 0 { unit(r.days, r.days == 1 ? "day" : "days") }
                    if r.days > 0 || r.hours > 0 { unit(r.hours, r.hours == 1 ? "hour" : "hours") }
                    unit(r.minutes, r.minutes == 1 ? "minute" : "minutes")
                }

                // Spelled out underneath: a row of numerals is easy to misread, and
                // this is the sentence VoiceOver should get.
                Text(sentence(r))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func sentence(_ r: (days: Int, hours: Int, minutes: Int)) -> String {
        if r.days > 0 {
            let hours = r.hours > 0 ? " and \(Self.plural(r.hours, "hour"))" : ""
            return "About \(Self.plural(r.days, "day"))\(hours) to go."
        }
        if r.hours > 0 {
            return "\(Self.plural(r.hours, "hour")) and \(Self.plural(r.minutes, "minute")) to go."
        }
        return "\(Self.plural(r.minutes, "minute")) to go."
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 68)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Days away") {
    CustomerCollectionCountdown(date: "2099-07-31", start: "09:00", end: "11:00").padding()
}
