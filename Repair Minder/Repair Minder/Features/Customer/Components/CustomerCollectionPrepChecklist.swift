//
//  CustomerCollectionPrepChecklist.swift
//  Repair Minder
//
//  Created on 26/07/2026.
//

import SwiftUI

/// What the seller needs to do to the device before we arrive.
///
/// Twin of `CollectionPrepChecklist.tsx` in the web portal - same three jobs, same
/// order, same links, same wording. The three things that actually stop a collection:
///
///  1. SOME CHARGE, so it can be powered on when it reaches the bench. First because
///     it is the one nobody thinks of.
///  2. NOT RESET - their data is still on it.
///  3. FIND MY still on - an activation lock only they can clear, and the single most
///     common reason a sale stalls.
///
/// DO NOT say the device is tested "on the spot" here. This card is only ever shown
/// for a DOORSTEP collection, where the device is taken away and checked at the shop.
/// Testing while the seller waits is the VISIT route, and that wording was wrongly
/// copied onto this card in the first draft.
///
/// The ticks are the seller's own reminder, kept in UserDefaults per ticket. They are
/// NOT sent anywhere and must never be read as us knowing the device is ready - only
/// the bench can tell us that. Nothing here gates anything.
///
/// Copy rules: UK English, hyphens only, "device" rather than "phone".
struct CustomerCollectionPrepChecklist: View {

    let ticketId: String

    private struct Task: Identifiable {
        let id: String
        let title: String
        let detail: String
        let linkLabel: String?
        let linkUrl: String?
    }

    private static let tasks: [Task] = [
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

    private var storageKey: String { "rm_collection_prep_\(ticketId)" }

    @State private var done: Set<String> = []

    private var remaining: Int { Self.tasks.count - Self.tasks.filter { done.contains($0.id) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Before we arrive")
                    .font(.headline)
                Spacer()
                Text(remaining == 0 ? "All done" : "\(remaining) of \(Self.tasks.count) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Self.tasks) { task in
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
