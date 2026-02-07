//
//  CompanySelectionView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// View for customers to select which company to log into
/// Shown when a customer has accounts with multiple repair shops
struct CompanySelectionView: View {
    @ObservedObject private var customerAuth = CustomerAuthManager.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Select a Shop")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("You have accounts with multiple repair shops.\nChoose one to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Company list
            VStack(spacing: 12) {
                ForEach(customerAuth.availableCompanies) { company in
                    CompanyRow(company: company) {
                        selectCompany(company)
                    }
                }
            }

            if let error = customerAuth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if customerAuth.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding(.horizontal, 24)
    }

    private func selectCompany(_ company: CompanySelectionItem) {
        Task {
            do {
                try await customerAuth.selectCompany(company.id)
            } catch {
                // Error handled by customerAuth.errorMessage
            }
        }
    }
}

// MARK: - Company Row

private struct CompanyRow: View {
    let company: CompanySelectionItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Logo or placeholder
                if let logoUrl = company.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure, .empty:
                            companyInitials
                        @unknown default:
                            companyInitials
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    companyInitials
                }

                Text(company.name)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var companyInitials: some View {
        Text(String(company.name.prefix(2)).uppercased())
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    CompanySelectionView()
}
