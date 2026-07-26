//
//  CustomerCollectionPrepChecklist.swift
//  Repair Minder
//
//  Created on 26/07/2026.
//

import SwiftUI

/// What the customer needs to do to the device before we arrive.
///
/// Twin of `CollectionPrepChecklist.tsx` in the web portal - same two task
/// lists, same order, same links, same wording. `kind` forks the list: a sell
/// device gets the three things that actually stop a collection (some charge,
/// a factory reset, Find My removed); a repair device gets the inverse (some
/// charge, Stolen Device Protection off, passcode kept on, backed up but NOT
/// reset) because it comes back to the same owner working.
///
/// DO NOT say the device is tested "on the spot" here. This card is only ever shown
/// for a DOORSTEP collection, where the device is taken away and checked at the shop.
/// Testing while the customer waits is the VISIT route, and that wording was wrongly
/// copied onto this card in the first draft.
///
/// The ticks are the customer's own reminder, kept in UserDefaults per ticket. They
/// are NOT sent anywhere and must never be read as us knowing the device is ready -
/// only the bench can tell us that. Nothing here gates anything.
///
/// Copy rules: UK English, hyphens only, "device" rather than "phone".
struct CustomerCollectionPrepChecklist: View {

    let ticketId: String

    /// `enquiry_kind` off the enquiry. 'repair_order' gets the inverse checklist:
    /// a repair device must NOT be reset and must keep its passcode, because it
    /// comes back to the same owner working. Anything else (sell, or an absent
    /// kind on old data) keeps the sell list.
    var kind: String? = nil

    private struct Task: Identifiable {
        let id: String
        let title: String
        let detail: String
        let linkLabel: String?
        let linkUrl: String?
    }

    private static let sellTasks: [Task] = [
        Task(
            id: "charge",
            title: "Give it some charge",
            detail: "Try to leave it with some charge if you can. We need to power it on to check it over, so a flat one holds your offer up.",
            linkLabel: nil,
            linkUrl: nil
        ),
        Task(
            id: "reset",
            title: "Factory reset it",
            detail: "Back up anything you would miss first, then reset the device and take out the SIM and any memory card.",
            linkLabel: "How to wipe your device",
            linkUrl: "https://mendmyi.com/blog/how-to-wipe-your-phone-before-selling"
        ),
        Task(
            id: "findmy",
            title: "Sign out and remove Find My",
            detail: "Sign out of iCloud or your Google account. If the device is already reset, or you cannot get into it, you can remove it from another phone, tablet or computer instead. If it is not in the list on that other device, it has already been removed and there is nothing to do.",
            linkLabel: "How to remove a device",
            // Apple's own instructions for removing a device from the list. NOT
            // icloud.com/find, which is the tool rather than the instructions.
            linkUrl: "https://support.apple.com/en-gb/guide/iphone/ipha94b7686e/ios"
        ),
    ]

    // A repair device must NOT be reset, and the passcode must survive: we power
    // it on and test it after the repair. Stolen Device Protection blocks the
    // diagnostic that records what was working before we started.
    //
    // Shape and wording are the portal's `REPAIR_TASKS` exactly: the
    // checklist-only charge reminder first, then the canonical four prep steps
    // in order, each one's `title`/`detail` taken verbatim from the `title`/
    // `body` of `REPAIR_PREP_STEPS` in `src/lib/repairPrep.ts`. The charge
    // reminder is checklist-only because it matters when we are about to
    // arrive, and does not belong in the four-step instruction the emails
    // carry. Change the wording in the canonical steps, change it here.
    private static let repairTasks: [Task] = [
        Task(
            id: "charge",
            title: "Give it some charge",
            detail: "Try to leave it with some charge if you can. We need to power it on to test it, so a flat one holds the repair up.",
            linkLabel: nil,
            linkUrl: nil
        ),
        Task(
            id: "sdp",
            title: "Turn off Stolen Device Protection",
            detail: "We run a full diagnostic that tests every feature before the repair and again once it is finished, so you can see what was working when it reached us. This feature blocks that diagnostic from completing. You will find it in Settings, then Face ID and Passcode.",
            linkLabel: "Apple: Stolen Device Protection",
            linkUrl: "https://support.apple.com/en-gb/120340"
        ),
        Task(
            id: "passcode",
            title: "Leave the passcode switched on, and tell us what it is",
            detail: "Taking it off works just as well. Either way we need to be able to get in, because we power the device on and test it after the repair.",
            linkLabel: nil,
            linkUrl: nil
        ),
        Task(
            id: "noreset",
            title: "Please do not factory reset it",
            detail: "We are repairing it, not buying it, so a reset only loses you your data.",
            linkLabel: nil,
            linkUrl: nil
        ),
        Task(
            id: "backup",
            title: "Back up anything you would miss, and take the SIM out",
            detail: "Take any memory card out too, and keep hold of the case, the cable and the charger: we do not need them.",
            linkLabel: nil,
            linkUrl: nil
        ),
    ]

    private var tasks: [Task] {
        kind == CustomerEnquiryKind.repairOrder ? Self.repairTasks : Self.sellTasks
    }

    private var storageKey: String { "rm_collection_prep_\(ticketId)" }

    @State private var done: Set<String> = []

    private var remaining: Int { tasks.count - tasks.filter { done.contains($0.id) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Before we arrive")
                    .font(.headline)
                Spacer()
                Text(remaining == 0 ? "All done" : "\(remaining) of \(tasks.count) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(tasks) { task in
                VStack(alignment: .leading, spacing: 6) {
                    // The whole row is the control, so a thumb has the full width to
                    // aim at rather than a small checkbox.
                    Button {
                        toggle(task.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: done.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done.contains(task.id) ? Color.green : Color.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .strikethrough(done.contains(task.id))
                                Text(task.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // OUTSIDE the toggle, deliberately: a link nested in the button
                    // would tick the job off when someone only wanted to read how to
                    // do it. Same reasoning as the web twin.
                    if let label = task.linkLabel, let urlString = task.linkUrl,
                       let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label(label, systemImage: "arrow.up.right.square")
                                .font(.footnote)
                        }
                        .padding(.leading, 34)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(done.contains(task.id) ? Color.green.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(done.contains(task.id) ? Color.green.opacity(0.35) : Color.secondary.opacity(0.25), lineWidth: 1)
                )
            }

            Text("These ticks are just for you - they are not sent to us, and we check the device when it reaches us either way.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: load)
    }

    private func load() {
        // A value a user could in principle have corrupted is treated as absent
        // rather than trusted, matching the web twin's guard.
        let stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        done = Set(stored)
    }

    private func toggle(_ id: String) {
        if done.contains(id) { done.remove(id) } else { done.insert(id) }
        UserDefaults.standard.set(Array(done), forKey: storageKey)
    }
}

#Preview {
    CustomerCollectionPrepChecklist(ticketId: "preview-ticket").padding()
}
