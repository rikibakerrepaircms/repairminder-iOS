//
//  PoDocument.swift
//  Repair Minder
//
//  Created on 03/06/2026.
//

import Foundation

struct PoDocument: Codable, Identifiable {
    let id: String
    let filename: String
    let contentType: String
    let sizeBytes: Int
    let uploadedAt: String

    var formattedSize: String {
        if sizeBytes < 1024 { return "\(sizeBytes) B" }
        if sizeBytes < 1024 * 1024 { return "\(sizeBytes / 1024) KB" }
        return String(format: "%.1f MB", Double(sizeBytes) / 1024 / 1024)
    }
}
