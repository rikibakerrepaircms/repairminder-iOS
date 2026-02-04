//
//  PaymentDueCard.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct PaymentDueCard: View {
    let balance: Decimal
    let deposit: Decimal?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Payment Due")
                    .font(.headline)

                Spacer()
            }

            VStack(spacing: 8) {
                if let deposit = deposit, deposit > 0 {
                    HStack {
                        Text("Deposit paid")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(deposit.formatted(.currency(code: "GBP")))
                    }
                    .font(.subheadline)

                    Divider()
                }

                HStack {
                    Text("Balance due")
                        .fontWeight(.medium)
                    Spacer()
                    Text(balance.formatted(.currency(code: "GBP")))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }

            Text("Payment will be collected when you pick up your device")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

#Preview {
    PaymentDueCard(balance: 149.99, deposit: 50.00)
}
