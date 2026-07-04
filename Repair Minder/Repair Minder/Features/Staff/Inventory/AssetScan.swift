import Foundation

/// Parses raw scanner output (QR code or barcode payload) into an asset tag.
///
/// Mirrors the web app's `parseAssetScanUrl` (src/utils/assetScanUtils.ts):
/// - Printed asset labels encode a QR code pointing at
///   `https://<host>/scan/asset/<TAG>` (optionally with query params, e.g.
///   `?context=order&id=...`), and a CODE128 barcode encoding the raw tag.
/// - Asset tags are 3 letters followed by 9 digits (e.g. `AST000000001`).
///
/// If the scanned string contains a `/scan/asset/<TAG>` path segment, the tag
/// is extracted from there (ignoring any query string). Otherwise, if the
/// whole trimmed string itself is a bare tag, it is normalized (uppercased).
/// Anything else is returned trimmed but otherwise unchanged, so unrecognized
/// formats still get passed through to the lookup call unmodified.
enum AssetScan {
    private static let tagPattern = "[A-Za-z]{3}\\d{9}"

    static func parse(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let urlTag = extractTag(fromPathPattern: "/scan/asset/(\(tagPattern))", in: trimmed) {
            return urlTag
        }

        if let range = trimmed.range(of: "^\(tagPattern)$", options: .regularExpression) {
            return String(trimmed[range]).uppercased()
        }

        return trimmed
    }

    private static func extractTag(fromPathPattern pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let tagRange = Range(match.range(at: 1), in: string) else {
            return nil
        }
        return String(string[tagRange]).uppercased()
    }
}
