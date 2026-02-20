//
//  AuthenticatedImageView.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import SwiftUI

/// Loads an image from the buyback images endpoint with Bearer token auth.
/// Standard AsyncImage doesn't support custom headers, so this uses URLSession directly.
struct AuthenticatedImageView: View {
    let imageId: String
    let width: Int
    let height: Int

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        guard let url = buildURL() else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        guard let token = AuthManager.shared.accessToken else {
            isLoading = false
            return
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let uiImage = UIImage(data: data) else {
                isLoading = false
                return
            }
            self.image = uiImage
        } catch {
            #if DEBUG
            print("[AuthenticatedImage] Failed to load image \(imageId): \(error)")
            #endif
        }

        isLoading = false
    }

    private func buildURL() -> URL? {
        var components = URLComponents(string: "https://api.repairminder.com/api/buyback/images/\(imageId)/file")
        components?.queryItems = [
            URLQueryItem(name: "w", value: "\(width)"),
            URLQueryItem(name: "h", value: "\(height)"),
            URLQueryItem(name: "format", value: "auto")
        ]
        return components?.url
    }
}
