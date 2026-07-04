import Foundation

struct KioskTotals: Equatable, Sendable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
    let discountTotal: Double
    let globalDiscount: Double
    let amountPaid: Double
    let balanceDue: Double
}

struct KioskComputedLine: Sendable {
    let item: KioskCartItem
    let lineTotal: Double
    let vatAmount: Double
    let lineTotalIncVat: Double
    let effectiveDiscount: Double
}

enum KioskCartMath {
    /// Mirrors JS `Math.round(x*100)/100` (round half toward +∞).
    static func jsRound2(_ x: Double) -> Double {
        return (x * 100 + 0.5).rounded(.down) / 100
    }

    static func computeLineItem(_ item: KioskCartItem) -> KioskComputedLine {
        let quantity = Double(item.quantity <= 0 ? 1 : item.quantity)
        let unitPrice = item.unitPrice
        let vatRate = item.vatRate

        let grossTotal = jsRound2(quantity * unitPrice)
        let effectiveDiscount: Double
        if let pct = item.discountPercent, pct != 0 {
            effectiveDiscount = jsRound2(grossTotal * (pct / 100))
        } else {
            effectiveDiscount = min(item.discountAmount ?? 0, grossTotal)
        }
        let lineTotal = jsRound2(grossTotal - effectiveDiscount)
        let lineTotalIncVat = jsRound2(quantity * unitPrice * (1 + vatRate / 100))
            - jsRound2(effectiveDiscount * (1 + vatRate / 100))
        let vatAmount = jsRound2(lineTotalIncVat - lineTotal)

        return KioskComputedLine(item: item, lineTotal: lineTotal, vatAmount: vatAmount,
                                 lineTotalIncVat: lineTotalIncVat, effectiveDiscount: effectiveDiscount)
    }

    static func computeCartTotals(_ items: [KioskCartItem],
                                  globalDiscountPercent: Double?,
                                  globalDiscountAmount: Double?) -> KioskTotals {
        let computed = items.map(computeLineItem)

        var itemsSubtotal = 0.0, itemsVatTotal = 0.0, totalItemDiscounts = 0.0
        for c in computed {
            itemsSubtotal += c.lineTotal
            itemsVatTotal += c.vatAmount
            totalItemDiscounts += c.effectiveDiscount
        }
        itemsSubtotal = jsRound2(itemsSubtotal)
        itemsVatTotal = jsRound2(itemsVatTotal)

        var globalDiscountValue = 0.0
        if let pct = globalDiscountPercent, pct != 0 {
            globalDiscountValue = jsRound2(itemsSubtotal * (pct / 100))
        } else if let amt = globalDiscountAmount, amt != 0 {
            globalDiscountValue = jsRound2(min(amt, itemsSubtotal))
        }

        let adjustedSubtotal: Double, adjustedVat: Double, grandTotal: Double
        if globalDiscountValue > 0 {
            adjustedSubtotal = jsRound2(itemsSubtotal - globalDiscountValue)
            let effectiveVatRate = itemsSubtotal > 0 ? (itemsVatTotal / itemsSubtotal) : 0
            adjustedVat = jsRound2(adjustedSubtotal * effectiveVatRate)
            grandTotal = jsRound2(adjustedSubtotal + adjustedVat)
        } else {
            adjustedSubtotal = itemsSubtotal
            adjustedVat = itemsVatTotal
            grandTotal = jsRound2(itemsSubtotal + itemsVatTotal)
        }

        return KioskTotals(
            subtotal: adjustedSubtotal,
            vatTotal: adjustedVat,
            grandTotal: grandTotal,
            discountTotal: jsRound2(totalItemDiscounts + globalDiscountValue),
            globalDiscount: globalDiscountValue,
            amountPaid: 0,
            balanceDue: grandTotal)
    }
}
