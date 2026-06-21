// Features/Diagnostics/Report/DiagnosticReport.swift
// Pure, platform-agnostic report model + HTML renderer for the diagnostic PDF.
// Kept free of UIKit/WebKit so it is fully unit-testable; the iOS-only PDF rendering
// and share plumbing live in DiagnosticReportPDF.swift.
import Foundation

/// A flattened, render-ready snapshot of a finished diagnostic session.
struct DiagnosticReportData: Sendable {
    /// One test result with its human-readable detail rows.
    struct Item: Sendable {
        let id: String
        let name: String
        let status: TestStatus
        let details: [(label: String, value: String)]
    }

    let deviceName: String            // marketing name (e.g. "iPhone 15 Pro") or generic "iPhone"
    let osName: String?               // "iOS"
    let osVersion: String?            // "17.5"
    let batteryLevel: String?         // "87" (percent, no sign)
    let batteryState: String?         // "charging" / "unplugged" / ...
    let generatedAt: Date
    let overall: String               // "pass" / "partial" / "fail"
    let grade: DiagnosticGrade
    let passed: [Item]                // status == .pass
    let failed: [Item]                // status == .fail || .error
    let skipped: [Item]               // status == .skip || .partial
    /// Key/value identity rows for the "Device information" table.
    let deviceInfoRows: [(label: String, value: String)]

    var passedCount: Int { passed.count }
    var failedCount: Int { failed.count }
    var skippedCount: Int { skipped.count }
    var totalCount: Int { passedCount + failedCount + skippedCount }
}

extension DiagnosticReportData {
    /// Build report data from a finished runner. `deviceName` should be the best available
    /// marketing name (see DeviceModelName); falls back to the device_info model if empty.
    @MainActor
    static func from(runner: DiagnosticRunner, deviceName: String, generatedAt: Date) -> DiagnosticReportData {
        let outcomes = runner.orderedOutcomes
        let info = runner.outcome(for: "device_info")?.details ?? [:]

        func items(_ filter: (TestStatus) -> Bool) -> [Item] {
            outcomes.filter { filter($0.status) }.map { o in
                Item(id: o.id, name: o.name, status: o.status,
                     details: ReportDetailFormatter.rows(for: o.details))
            }
        }

        let model = info["model"].flatMap { $0.isEmpty ? nil : $0 }
        let resolvedName = deviceName.isEmpty ? (model ?? "Device") : deviceName

        // Device-information table: identity fields we actually have on-device.
        var infoRows: [(label: String, value: String)] = []
        if !resolvedName.isEmpty { infoRows.append(("Device", resolvedName)) }
        if let m = model, m != resolvedName { infoRows.append(("Reported Model", m)) }
        if let os = info["os_version"], !os.isEmpty {
            let osName = info["name"].flatMap { $0.isEmpty ? nil : $0 } ?? "iOS"
            infoRows.append(("System Version", "\(osName) \(os)"))
        }
        if let lvl = info["battery_level"], !lvl.isEmpty { infoRows.append(("Battery Level", "\(lvl)%")) }
        if let st = info["battery_state"], !st.isEmpty {
            infoRows.append(("Battery State", st.capitalized))
        }
        // Surface storage from the storage test if it ran.
        if let storage = runner.outcome(for: "storage")?.details {
            if let t = storage["total"], !t.isEmpty { infoRows.append(("Storage Capacity", t)) }
            if let f = storage["free"], !f.isEmpty { infoRows.append(("Storage Free", f)) }
        }

        return DiagnosticReportData(
            deviceName: resolvedName,
            osName: info["name"].flatMap { $0.isEmpty ? nil : $0 },
            osVersion: info["os_version"].flatMap { $0.isEmpty ? nil : $0 },
            batteryLevel: info["battery_level"].flatMap { $0.isEmpty ? nil : $0 },
            batteryState: info["battery_state"].flatMap { $0.isEmpty ? nil : $0 },
            generatedAt: generatedAt,
            overall: runner.overallResult,
            grade: runner.grade,
            passed: items { $0 == .pass },
            failed: items { $0 == .fail || $0 == .error },
            skipped: items { $0 == .skip || $0 == .partial },
            deviceInfoRows: infoRows
        )
    }
}

/// Turns a test's raw `details` map into ordered, human-readable label/value rows.
enum ReportDetailFormatter {
    /// Keys to float to the top (in this order) when present; everything else is alphabetical.
    private static let priority = ["model", "os_version", "total", "free", "used",
                                   "battery_level", "battery_state", "health_percent",
                                   "cycle_count", "max_touches", "number_of_touches"]

    /// Friendly labels for keys whose prettified form reads poorly.
    private static let labels: [String: String] = [
        "os_version": "OS Version", "battery_level": "Battery Level",
        "battery_state": "Battery State", "max_touches": "Max Touches",
        "number_of_touches": "Touches", "health_percent": "Health",
        "cycle_count": "Cycle Count", "max_capacity_mah": "Max Capacity",
        "voltage_mv": "Voltage", "temperature_c": "Temperature",
        "accel_peak_g": "Peak Acceleration", "lux_baseline": "Light (baseline)",
        "lux_peak": "Light (peak)", "qr_detected": "QR Detected",
        "low_power_mode": "Low Power Mode", "thermal_state": "Thermal State",
        "drain_percent_per_hour": "Drain (per hour)", "faceid_status": "Face ID Status",
    ]

    /// Values that mean "no data" and should be hidden rather than printed.
    private static let emptyValues: Set<String> = ["", "n/a", "na", "none", "unknown"]

    static func label(for key: String) -> String {
        if let l = labels[key] { return l }
        return key.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func value(for key: String, _ raw: String) -> String {
        switch key {
        case "battery_level", "health_percent", "drain_percent", "delta_pct":
            return raw.hasSuffix("%") ? raw : "\(raw)%"
        case "voltage_mv":      return "\(raw) mV"
        case "temperature_c":   return "\(raw)°C"
        case "max_capacity_mah": return "\(raw) mAh"
        default:                return raw
        }
    }

    static func rows(for details: [String: String]?) -> [(label: String, value: String)] {
        guard let details else { return [] }
        let keep = details.filter { !emptyValues.contains($0.value.lowercased().trimmingCharacters(in: .whitespaces)) }
        let sortedKeys = keep.keys.sorted { a, b in
            let ia = priority.firstIndex(of: a) ?? Int.max
            let ib = priority.firstIndex(of: b) ?? Int.max
            return ia == ib ? a < b : ia < ib
        }
        return sortedKeys.map { (label: label(for: $0), value: value(for: $0, keep[$0]!)) }
    }
}

/// Branding/asset payload for the HTML renderer. Logos are passed as `data:` URIs so the
/// renderer stays asset-free and testable; nil falls back to a text wordmark.
struct DiagnosticReportAssets: Sendable {
    var repairMinderLogoDataURI: String?
    var mendmyiLogoDataURI: String?
    init(repairMinderLogoDataURI: String? = nil, mendmyiLogoDataURI: String? = nil) {
        self.repairMinderLogoDataURI = repairMinderLogoDataURI
        self.mendmyiLogoDataURI = mendmyiLogoDataURI
    }
}

/// Renders `DiagnosticReportData` into a print-ready, A4 HTML document (RepairMinder /
/// mendmyi branded). Study target was a competitor certification report; layout/structure
/// only — no third-party marks appear here.
enum DiagnosticReportHTML {
    /// RepairMinder + mendmyi share a blue wordmark (~#0090F0) with a neutral grey.
    private enum Palette {
        static let brand = "#0090F0"
        static let brandDark = "#0A6FBF"
        static let ink = "#1c1c22"
        static let grey = "#606066"
        static let line = "#e3e6ea"
        static let pass = "#2f9e44"
        static let fail = "#e03131"
        static let skip = "#868e96"
        static let passBg = "#eafaf0"
        static let failBg = "#fff0f0"
        static let skipBg = "#f3f4f6"
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func verdictLabel(_ overall: String) -> String {
        switch overall { case "pass": return "Pass"; case "partial": return "Partial"; default: return "Fail" }
    }
    private static func verdictColor(_ overall: String) -> String {
        switch overall { case "pass": return Palette.pass; case "partial": return Palette.skip; default: return Palette.fail }
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM yyyy 'at' HH:mm"
        return f.string(from: date)
    }

    private static func statusBadge(_ status: TestStatus) -> (label: String, color: String) {
        switch status {
        case .pass:           return ("PASS", Palette.pass)
        case .fail, .error:   return ("FAIL", Palette.fail)
        case .skip, .partial: return ("SKIP", Palette.skip)
        }
    }

    private static func itemRow(_ item: DiagnosticReportData.Item) -> String {
        let badge = statusBadge(item.status)
        let detailHTML: String
        if item.details.isEmpty {
            detailHTML = ""
        } else {
            let parts = item.details.map {
                "<span class=\"k\">\(esc($0.label))</span> \(esc($0.value))"
            }.joined(separator: "<span class=\"sep\">·</span>")
            detailHTML = "<div class=\"detail\">\(parts)</div>"
        }
        return """
        <div class="item">
          <div class="item-head">
            <span class="dot" style="background:\(badge.color)"></span>
            <span class="item-name">\(esc(item.name))</span>
            <span class="item-badge" style="color:\(badge.color)">\(badge.label)</span>
          </div>
          \(detailHTML)
        </div>
        """
    }

    private static func section(title: String, color: String, bg: String, items: [DiagnosticReportData.Item]) -> String {
        guard !items.isEmpty else { return "" }
        let rows = items.map(itemRow).joined()
        return """
        <section class="card" style="--accent:\(color);--accent-bg:\(bg)">
          <h2 class="card-title">\(esc(title)) <span class="count">\(items.count)</span></h2>
          \(rows)
        </section>
        """
    }

    /// Produce the full HTML document string.
    static func render(_ data: DiagnosticReportData, assets: DiagnosticReportAssets = .init()) -> String {
        let verdict = verdictLabel(data.overall)
        let vColor = verdictColor(data.overall)

        let rmLogo: String
        if let uri = assets.repairMinderLogoDataURI {
            rmLogo = "<img class=\"rm-logo\" src=\"\(uri)\" alt=\"Repair Minder\"/>"
        } else {
            rmLogo = "<div class=\"rm-word\">Repair<span>Minder</span></div>"
        }
        let mendmyiLogo: String
        if let uri = assets.mendmyiLogoDataURI {
            mendmyiLogo = "<img class=\"mm-logo\" src=\"\(uri)\" alt=\"mendmyi\"/>"
        } else {
            mendmyiLogo = "<span class=\"mm-word\">mendmyi</span>"
        }

        let batteryChip: String
        if let lvl = data.batteryLevel {
            batteryChip = "<div class=\"banner-batt\"><div class=\"batt-pct\">\(esc(lvl))%</div><div class=\"batt-cap\">Battery (current charge)</div></div>"
        } else {
            batteryChip = ""
        }

        let deviceSub: String = {
            var parts: [String] = []
            if let os = data.osVersion { parts.append("\(esc(data.osName ?? "iOS")) \(esc(os))") }
            return parts.joined(separator: " · ")
        }()

        let deviceInfoTable: String = {
            guard !data.deviceInfoRows.isEmpty else { return "" }
            let rows = data.deviceInfoRows.map {
                "<tr><td class=\"di-k\">\(esc($0.label))</td><td class=\"di-v\">\(esc($0.value))</td></tr>"
            }.joined()
            return """
            <section class="card di-card" style="--accent:\(Palette.brand);--accent-bg:#eef6fd">
              <h2 class="card-title">Device Information</h2>
              <table class="di-table">\(rows)</table>
              <p class="di-note">Full hardware identity — IMEI, serial number and battery cycle/health —
              is read by the in-shop RepairMinder computer and is not available to the mobile app.</p>
            </section>
            """
        }()

        let passedSec = section(title: "Passed", color: Palette.pass, bg: Palette.passBg, items: data.passed)
        let failedSec = section(title: "Failed", color: Palette.fail, bg: Palette.failBg, items: data.failed)
        let skippedSec = section(title: "Skipped", color: Palette.skip, bg: Palette.skipBg, items: data.skipped)
        // Failures first (most important), then skipped, then passed — mirrors the on-screen Summary.
        let resultsBody = [failedSec, skippedSec, passedSec].joined()

        return """
        <!DOCTYPE html>
        <html lang="en"><head><meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <style>
          @page { size: A4; margin: 14mm; }
          * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
          html,body { margin:0; padding:0; }
          body { font-family:-apple-system,"Helvetica Neue",Arial,sans-serif; color:\(Palette.ink);
                 font-size:12px; line-height:1.45; }
          .header { display:flex; align-items:center; justify-content:space-between;
                    border-bottom:3px solid \(Palette.brand); padding-bottom:12px; margin-bottom:16px; }
          .rm-logo { height:38px; }
          .rm-word { font-size:24px; font-weight:800; color:\(Palette.ink); }
          .rm-word span { color:\(Palette.brand); }
          .header-meta { text-align:right; }
          .header-title { font-size:18px; font-weight:800; color:\(Palette.brandDark); letter-spacing:-.2px; }
          .header-sub { font-size:11px; color:\(Palette.grey); }

          .verdict { display:flex; align-items:stretch; gap:14px; margin-bottom:14px; }
          .verdict-badge { flex:0 0 auto; min-width:150px; border-radius:12px; padding:14px 18px;
                           color:#fff; background:\(vColor); display:flex; flex-direction:column; justify-content:center; }
          .verdict-badge .v-label { font-size:13px; opacity:.85; font-weight:600; }
          .verdict-badge .v-word { font-size:30px; font-weight:800; line-height:1; margin-top:2px; }
          .counts { flex:1; display:flex; gap:10px; }
          .count-box { flex:1; border:1px solid \(Palette.line); border-radius:12px; padding:10px 12px; text-align:center; }
          .count-box .n { font-size:24px; font-weight:800; }
          .count-box .l { font-size:11px; color:\(Palette.grey); text-transform:uppercase; letter-spacing:.4px; }
          .count-box.pass .n { color:\(Palette.pass); }
          .count-box.fail .n { color:\(Palette.fail); }
          .count-box.skip .n { color:\(Palette.skip); }

          .banner { display:flex; align-items:center; justify-content:space-between;
                    background:#f7f9fb; border:1px solid \(Palette.line); border-radius:12px;
                    padding:12px 16px; margin-bottom:16px; }
          .banner-name { font-size:18px; font-weight:700; }
          .banner-sub { font-size:12px; color:\(Palette.grey); margin-top:2px; }
          .banner-batt { text-align:right; }
          .batt-pct { font-size:22px; font-weight:800; color:\(Palette.brandDark); }
          .batt-cap { font-size:10px; color:\(Palette.grey); }

          .card { border:1px solid \(Palette.line); border-radius:12px; padding:0 14px 10px;
                  margin-bottom:14px; break-inside:avoid; }
          .card-title { font-size:13px; font-weight:700; text-transform:uppercase; letter-spacing:.5px;
                        color:#fff; background:var(--accent); margin:0 -14px 10px; padding:8px 14px;
                        border-radius:12px 12px 0 0; }
          .card-title .count { float:right; background:rgba(255,255,255,.25); border-radius:10px;
                               padding:0 9px; font-size:12px; }
          .item { padding:7px 0; border-bottom:1px solid #f0f2f4; }
          .item:last-child { border-bottom:none; }
          .item-head { display:flex; align-items:center; gap:8px; }
          .dot { width:9px; height:9px; border-radius:50%; flex:0 0 auto; }
          .item-name { font-weight:600; flex:1; }
          .item-badge { font-size:10px; font-weight:800; letter-spacing:.5px; }
          .detail { margin:3px 0 0 17px; color:\(Palette.grey); font-size:11px; }
          .detail .k { color:\(Palette.ink); font-weight:600; }
          .detail .sep { margin:0 6px; color:#c8ccd2; }

          .di-card .card-title { color:#fff; }
          .di-table { width:100%; border-collapse:collapse; }
          .di-table td { padding:5px 0; border-bottom:1px solid #f0f2f4; font-size:11.5px; vertical-align:top; }
          .di-k { color:\(Palette.grey); width:45%; }
          .di-v { text-align:right; font-weight:600; }
          .di-note { font-size:10px; color:\(Palette.grey); margin:9px 0 2px; line-height:1.4; }

          .footer { margin-top:18px; padding-top:12px; border-top:1px solid \(Palette.line);
                    display:flex; align-items:center; justify-content:space-between; }
          .footer-tag { font-size:11px; color:\(Palette.grey); }
          .mm-logo { height:20px; vertical-align:middle; }
          .mm-word { font-weight:700; color:\(Palette.brand); }
          .footer-date { font-size:10px; color:\(Palette.grey); }
        </style></head>
        <body>
          <div class="header">
            \(rmLogo)
            <div class="header-meta">
              <div class="header-title">Device Diagnostic Report</div>
              <div class="header-sub">Generated \(esc(dateString(data.generatedAt)))</div>
            </div>
          </div>

          <div class="verdict">
            <div class="verdict-badge">
              <span class="v-label">Overall result</span>
              <span class="v-word">\(esc(verdict))</span>
            </div>
            <div class="counts">
              <div class="count-box pass"><div class="n">\(data.passedCount)</div><div class="l">Passed</div></div>
              <div class="count-box fail"><div class="n">\(data.failedCount)</div><div class="l">Failed</div></div>
              <div class="count-box skip"><div class="n">\(data.skippedCount)</div><div class="l">Skipped</div></div>
            </div>
          </div>

          <div class="banner">
            <div>
              <div class="banner-name">\(esc(data.deviceName))</div>
              <div class="banner-sub">\(deviceSub)</div>
            </div>
            \(batteryChip)
          </div>

          \(resultsBody)
          \(deviceInfoTable)

          <div class="footer">
            <div class="footer-tag">\(mendmyiLogo) &nbsp;Repair Minder is a mendmyi Platform</div>
            <div class="footer-date">\(esc(dateString(data.generatedAt)))</div>
          </div>
        </body></html>
        """
    }

    /// Suggested PDF file name, e.g. `RepairMinder-Diagnostics-20260621-1342.pdf`.
    static func fileName(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        return "RepairMinder-Diagnostics-\(f.string(from: date)).pdf"
    }
}
