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
                    Label(slot.isRequested ? "Offer this window" : "Offer a new window",
                          systemImage: "paperplane")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(chosenStart.isEmpty || isBusy || isSunday(chosenDay))

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
