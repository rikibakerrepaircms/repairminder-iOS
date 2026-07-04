import Foundation

/// Builds a CSV of selected assets for the bulk "Export CSV" action, matching the
/// web `handleExportCSV` columns. Pure `csvString` (testable) + a temp-file writer
/// consumed by the iOS share sheet.
enum CSVExporter {
    static let header = "Asset Tag,Name,Status,Category,Location,Sub-Location,Serial Number,SKU,Condition,Cost"

    static func csvString(for assets: [Asset]) -> String {
        var rows = [header]
        for a in assets {
            let cost = a.cost.map { String($0) } ?? ""
            let fields = [
                a.assetTag,
                a.name,
                // Intentional divergence from web: iOS exports human-readable status.displayName; web exports the raw status value. See spec Group E.
                a.status.displayName,
                a.category ?? "",
                a.locationName ?? "",
                a.subLocationCode ?? "",
                a.serialNumber ?? "",
                a.sku ?? "",
                a.conditionGrade ?? "",
                cost
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// Quote a field if it contains a comma, quote, or newline; double embedded quotes.
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    /// Write the CSV to a temp `.csv` file and return its URL (for the share sheet).
    static func writeTempFile(_ assets: [Asset], fileName: String = "assets-export.csv") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csvString(for: assets).data(using: .utf8)?.write(to: url)
        return url
    }
}
