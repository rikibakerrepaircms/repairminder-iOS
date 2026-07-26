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
    /// Once a window is out there the picker folds away. An identical form sitting
    /// under "waiting on the customer" reads as though the offer never sent.
    @State private var isEditing = false

    private var showsPicker: Bool { slot.isRequested || isEditing }

    private static let startTimes = ["09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00"]

    // MUST MATCH resolveOfferOutcome in worker/src/collection_slot.js, and the same
    // block in CollectionSlotPanel.tsx. The server decides between four outcomes and
    // the button has to say which one it will cause - this card previously only ever
    // said "Offer", so it could not tell a staff member that a press would book a van
    // outright or take away a window the customer had personally agreed.
    //
    // The boundary is the START of the window, at noon.
    private func halfDayOfStart(_ t: String) -> String {
        (Int(t.prefix(2)) ?? 0) < 12 ? "morning" : "afternoon"
    }

    /// The offer is exactly the day and half day they asked for.
    private var matchesRequest: Bool {
        guard let reqDate = slot.requestedDate, let reqWindow = slot.requestedWindow,
              !chosenStart.isEmpty else { return false }
        return Self.isoDay(chosenDay) == reqDate && halfDayOfStart(chosenStart) == reqWindow
    }

    /// Changing a window the customer confirmed. Never a booking, however well it fits
    /// the original request - they pressed "That time works" for the old one.
    private var movesAgreedWindow: Bool {
        guard slot.isConfirmed, !chosenStart.isEmpty else { return false }
        return !(Self.isoDay(chosenDay) == slot.offeredDate && chosenStart == slot.offeredStart)
    }

    private var booksOutright: Bool { !slot.isConfirmed && matchesRequest }

    private var helperText: String {
        if movesAgreedWindow {
            return "Emails the customer an apology with the new time and a link to confirm it, and puts the collection back to waiting on them. Nothing is reserved: no availability is tracked, so check the diary yourself first."
        }
        if booksOutright {
            return "This is the day and half day they asked for, so it books straight away - they are told it is agreed rather than asked to confirm. Nothing is reserved: no availability is tracked, so check the diary yourself first."
        }
        return "Emails the customer a link to confirm it or ask for another day. Nothing is reserved: no availability is tracked, so check the diary yourself first."
    }

    private var actionTitle: String {
        if booksOutright { return "Book this window" }
        if movesAgreedWindow { return "Move their collection" }
        return slot.isRequested ? "Offer this window" : "Offer a new window"
    }
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

            if !showsPicker {
                HStack(spacing: 10) {
                    Label(slot.offeredDescription ?? "", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Button("Change") { isEditing = true }
                        .font(.subheadline.weight(.semibold))
                        .disabled(isBusy)
                }

                Text(slot.isConfirmed
                     ? "The customer has agreed to this window. They can still change it in their portal."
                     : "Emailed to the customer with a link to confirm it or ask for another day. Nothing is reserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsPicker {
            VStack(alignment: .leading, spacing: 6) {
                Text("DAY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $chosenDay, in: dayRange, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                if isSunday(chosenDay) {
                    Text("We are closed on Sundays. Pick another day.")
                        .font(.caption).foregroundStyle(.red)
                } else if isSaturday(chosenDay) {
                    Text("Saturday is a half day, mornings only.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // A grid of windows rather than a dropdown. Seven options is few enough to
            // show, and "Pick a time..." hides the very thing being chosen.
            VStack(alignment: .leading, spacing: 6) {
                Text("TWO-HOUR WINDOW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Self.startTimes, id: \.self) { time in
                        let closed = isSaturday(chosenDay) && (Int(time.prefix(2)) ?? 0) >= 12
                        Button {
                            chosenStart = time
                        } label: {
                            VStack(spacing: 1) {
                                Text(time).font(.subheadline.weight(.semibold))
                                Text("to \(Self.endOf(time))").font(.caption2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.bordered)
                        .tint(chosenStart == time ? .accentColor : .secondary)
                        .disabled(closed || isBusy)
                        .opacity(closed ? 0.35 : 1)
                    }
                }
            }

            Button {
                onOffer(Self.isoDay(chosenDay), chosenStart)
            } label: {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Label(actionTitle, systemImage: "paperplane")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(chosenStart.isEmpty || isBusy || isSunday(chosenDay))

            // Taking away a window the customer personally agreed is the one action
            // here with a cost attached, so it says so before the press.
            if movesAgreedWindow, let start = slot.offeredStart, let end = slot.offeredEnd {
                Label(
                    "They have already agreed \(start) to \(end). Moving it now asks them to confirm all over again, and they get an email apologising for the change - so only do this if the agreed window really cannot happen.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Text(helperText)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .onChange(of: slot) { _, _ in
            // A fresh offer, or a customer changing their mind, arrives as a new slot.
            isEditing = false
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

    private func isSaturday(_ date: Date) -> Bool {
        Calendar.current.component(.weekday, from: date) == 7
    }

    /// The shop is shut, so a window on one cannot be offered at all.
    private func isSunday(_ date: Date) -> Bool {
        Calendar.current.component(.weekday, from: date) == 1
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
