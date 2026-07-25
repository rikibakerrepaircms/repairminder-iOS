import SwiftUI

/// Staff side of agreeing a doorstep collection window, on iPhone, iPad and Mac.
///
/// There is no availability here because nothing tracks it. Two sellers can be
/// offered the same window; this card does not pretend otherwise, and says so.
///
/// The start times are the shop's own hours: 09:00 to 17:00 weekdays, Saturday
/// mornings. A two-hour window from 15:00 is the last that fits a weekday.
///
/// No UIKit: this compiles into the Mac target, and an iOS-simulator build passing
/// would not prove that.
struct CollectionSlotOfferCard: View {

    let slot: CollectionSlot
    let isBusy: Bool
    let errorMessage: String?
    let onOffer: (String, String) -> Void

    @State private var chosenDay = Date()
    @State private var chosenStart: String = ""

    private static let startTimes = ["09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00"]
    private static let maxDaysAhead = 56

    private var dayRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: Self.maxDaysAhead, to: start) ?? start
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Doorstep collection", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                stateBadge
            }

            // Straight from the server, so staff and customer read the same sentence.
            if let summary = slot.summary {
                Text(summary).font(.subheadline)
            }

            if slot.state != "requested", let asked = slot.requestedDescription {
                Text("They originally asked for \(asked).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            DatePicker("Day", selection: $chosenDay, in: dayRange, displayedComponents: .date)

            Picker("Two-hour window", selection: $chosenStart) {
                Text("Pick a time...").tag("")
                ForEach(Self.startTimes, id: \.self) { time in
                    Text("\(time) to \(Self.endOf(time))").tag(time)
                }
            }

            Button {
                onOffer(Self.isoDay(chosenDay), chosenStart)
            } label: {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Label(slot.isRequested ? "Offer this window" : "Offer a new window",
                          systemImage: "paperplane")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(chosenStart.isEmpty || isBusy)

            Text("Emails the customer a link to confirm it or ask for another day. Nothing is reserved: no availability is tracked, so check the diary yourself first.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Start from the day they asked for, so the common case is pick a time and send.
            let seed = slot.offeredDate ?? slot.requestedDate
            if let seed, let parsed = Self.parseIsoDay(seed), dayRange.contains(parsed) {
                chosenDay = parsed
            }
            if let start = slot.offeredStart, Self.startTimes.contains(start) {
                chosenStart = start
            }
        }
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch slot.state {
        case "requested":
            badge("Needs a window", .orange)
        case "offered":
            badge("Waiting on the customer", .blue)
        case "confirmed":
            badge("Agreed", .green)
        default:
            EmptyView()
        }
    }

    private func badge(_ text: String, _ colour: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.15), in: Capsule())
            .foregroundStyle(colour)
    }

    private static func endOf(_ start: String) -> String {
        let parts = start.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return start }
        return String(format: "%02d:%02d", min(parts[0] + 2, 23), parts[1])
    }

    /// `YYYY-MM-DD` in the staff member's own calendar, which is what they mean by
    /// "Thursday" - not UTC, which can be the day before.
    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseIsoDay(_ iso: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }
}
