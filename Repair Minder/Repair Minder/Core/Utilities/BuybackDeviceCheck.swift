//
//  BuybackDeviceCheck.swift
//  Repair Minder
//

import Foundation

/// The gate that decides whether a buyback device may be added yet.
///
/// Buying a handset is the one intake where an unchecked device costs real money,
/// so the check has to have actually happened. But "happened" cannot mean
/// "succeeded": SICKW blocks Cloudflare egress, so the lookup can fail for reasons
/// that have nothing to do with the device in front of the counter. Refusing to
/// book the purchase in at all then just stops the shop trading.
///
/// So an attempt satisfies the gate - a clean result, or a provider we could not
/// reach. What must NOT happen is silently treating the failure as a pass: the
/// caller shows the unconfirmed-checks warning, and a CONFIRMED blacklist hit is a
/// separate block that this function never clears.
///
/// Skipping is allowed too, since SICKW is now blocked from Cloudflare's egress
/// range often enough that "press the button and wait for it to fail" was the
/// normal path rather than the exception - a gate that costs a minute and confirms
/// nothing. But a skip is an EXPLICIT act against a specific identifier, never a
/// default and never inherited by the next device: the operator says they are
/// booking it in unchecked, and the unconfirmed-checks warning says so on the row.
///
/// This is the Swift half of a contract shared with the web dashboard. The
/// canonical copy is `src/utils/buybackDeviceCheck.ts` in the repairminder repo,
/// and `BuybackCheckGateTests` mirrors its vectors. A purchase booked on the iPad
/// and the same purchase booked on the dashboard must accept and refuse the same
/// states, so the two implementations move together or not at all.
///
/// - Parameters:
///   - isBuybackDevice: Only buybacks are gated; a repair intake never pays for
///     the blacklist call.
///   - identifier: The IMEI or serial currently in the form.
///   - checkedIdentifiers: Identifiers the last completed lookup covered (the one
///     queried, plus anything it returned).
///   - checkedForBuyback: Was that completed lookup run in buyback mode? A
///     repair-mode check does not count.
///   - failedIdentifiers: Identifiers whose check ran and came back as an error
///     rather than a result.
///   - skippedIdentifiers: Identifiers the operator has deliberately chosen to
///     book in without checking.
/// - Returns: `true` while the device may NOT be added - the check has not been
///   run against this identifier.
func awaitingBuybackCheck(
    isBuybackDevice: Bool,
    identifier: String,
    checkedIdentifiers: [String],
    checkedForBuyback: Bool,
    failedIdentifiers: [String],
    skippedIdentifiers: [String] = []
) -> Bool {
    guard isBuybackDevice else { return false }

    let id = identifier.trimmingCharacters(in: .whitespaces)
    // Nothing typed yet, so nothing has been checked. Blocks either way, since a
    // buyback device needs a serial or IMEI regardless.
    if id.isEmpty { return true }

    if checkedForBuyback && checkedIdentifiers.contains(id) { return false }
    // Tried and could not reach the provider. Book it in by hand.
    if failedIdentifiers.contains(id) { return false }
    // Chose not to try. Same outcome, and the same warning on the row - the
    // difference is only in how it is recorded, which is the operator's to state.
    if skippedIdentifiers.contains(id) { return false }

    return true
}
