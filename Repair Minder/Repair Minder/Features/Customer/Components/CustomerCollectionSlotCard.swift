import SwiftUI

/// The customer's half of agreeing a doorstep collection window, on iPhone, iPad
/// and Mac.
///
/// Nothing here is a booking. The portal tells sellers "the day and half day you
/// chose is a request, not a booking", so this card must never say a slot is held -
/// only what was asked for, what has been offered, and what is agreed.
///
/// Note the two grains, which are easy to conflate: the SELLER picks a day and a
/// half day (SLOT_WINDOWS is ['morning', 'afternoon']), and WE offer back a
/// two-hour window they then confirm. Copy telling the seller they picked a
/// two-hour window is wrong.
///
/// Deliberately no UIKit: this compiles into the Mac target too, and an
/// iOS-simulator build passing would not prove that.
struct CustomerCollectionSlotCard: View {

    let slot: CollectionSlot
    let isBusy: Bool
    let errorMessage: String?
    /// Keys the prep checklist's saved ticks. Nil renders no checklist rather than
    /// sharing one set of ticks across every collection the seller has.
    var ticketId: String? = nil
    let onConfirm: () -> Void
    let onRequest: (String, String) -> Void

    @State private var isChanging = false
    @State private var chosenDay = Date()
    @State private var chosenWindow: String?

    /// Matches the storefront calendar and the server's own validation.
    private static let maxDaysAhead = 56

    private var dayRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: Self.maxDaysAhead, to: start) ?? start
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // An offered window is the one thing on this screen waiting on the
            // customer, so it says so. Every other state stays unadorned: 'requested'
            // is waiting on US and 'confirmed' is settled, so a chip on either would
            // ask for an action that does not exist. Twin of the "Waiting on you"
            // chip in CollectionSlotCard.tsx.
            HStack {
                Label("Your collection", systemImage: "calendar.badge.clock")
                    .font(.headline)

                if slot.isOffered {
                    Spacer()
                    Text("Waiting on you")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(Color.blue)
                        .clipShape(Capsule())
                }
            }

            statusText

            // Only on an AGREED collection. An offered window is not a promise yet,
            // so counting down to it would invent a commitment.
            if slot.isConfirmed {
                CustomerCollectionCountdown(
                    date: slot.offeredDate,
                    start: slot.offeredStart,
                    end: slot.offeredEnd
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                if slot.isOffered {
                    Button(action: onConfirm) {
                        if isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("That time works", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                }

                Button(slot.isOffered ? "Ask for another time" : "Change the day") {
                    isChanging.toggle()
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }

            // Below the actions, not above: someone opening this card with a date
            // agreed wants the countdown and the way to change it first, and the jobs
            // second. Hidden while the picker is open so the card has one focus.
            if slot.isConfirmed, let ticketId, !isChanging {
                Divider()
                CustomerCollectionPrepChecklist(ticketId: ticketId)
            }

            if isChanging {
                Divider()
                DatePicker("Which day suits you?",
                           selection: $chosenDay,
                           in: dayRange,
                           displayedComponents: .date)

                Text("Morning or afternoon?")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    ForEach(["morning", "afternoon"], id: \.self) { window in
                        Button {
                            chosenWindow = window
                        } label: {
                            Text(window.capitalized)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(chosenWindow == window ? .accentColor : .secondary)
                    }
                }

                Button("Ask for this time instead") {
                    guard let chosenWindow else { return }
                    onRequest(Self.isoDay(chosenDay), chosenWindow)
                    isChanging = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(chosenWindow == nil || isBusy)

                Text("We are closed Sundays, and Saturdays are mornings only. Changing is free and there is no limit on how many times you can do it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Start from what they last asked for, so the common case is one tap.
            if let requested = slot.requestedDate, let parsed = Self.parseIsoDay(requested),
               dayRange.contains(parsed) {
                chosenDay = parsed
            }
            chosenWindow = slot.requestedWindow
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if slot.isConfirmed, let when = slot.offeredDescription {
            Text("Agreed. We will collect on \(when). If that stops working, pick another day below and we will sort it.")
                .font(.subheadline)
        } else if slot.isOffered, let when = slot.offeredDescription {
            Text("We can collect on \(when). Nothing is fixed until you confirm it.")
                .font(.subheadline)
        } else {
            Text("You asked for \(slot.requestedDescription ?? "a collection"). We will email you a two-hour window to confirm, usually the same working day.")
                .font(.subheadline)
        }
    }

    /// `YYYY-MM-DD` in the user's own calendar, which is what the seller means by
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
