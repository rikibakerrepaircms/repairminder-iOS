//
//  AboutView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct AboutView: View {
    private let brand = BrandConfiguration.current

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            // App Header
            Section {
                VStack(spacing: 16) {
                    BrandLogo(size: .large)
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        Text(brand.displayName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            // Legal
            Section("Legal") {
                if let termsURL = brand.termsURL {
                    Link(destination: termsURL) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let privacyURL = brand.privacyURL {
                    Link(destination: privacyURL) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Support
            Section("Support") {
                if let supportURL = brand.supportURL {
                    Link(destination: supportURL) {
                        HStack {
                            Label("Help Center", systemImage: "questionmark.circle")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Link(destination: URL(string: "mailto:\(brand.supportEmail)")!) {
                    HStack {
                        Label("Contact Support", systemImage: "envelope")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Credits
            Section {
                VStack(spacing: 8) {
                    Text("Made with love by")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(brand.companyName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(brand.companyLocation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
