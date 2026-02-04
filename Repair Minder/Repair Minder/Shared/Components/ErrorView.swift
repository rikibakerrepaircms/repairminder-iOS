//
//  ErrorView.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI

struct ErrorView: View {
    let error: String
    var retryAction: (() -> Void)?

    init(error: String, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    init(message: String, retryAction: (() -> Void)? = nil) {
        self.error = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorView(error: "Network connection failed") {
        print("Retry tapped")
    }
}

#Preview("No Retry") {
    ErrorView(error: "Unable to load data")
}
