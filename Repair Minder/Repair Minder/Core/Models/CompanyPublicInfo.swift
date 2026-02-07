//
//  CompanyPublicInfo.swift
//  Repair Minder
//

import Foundation

/// Response from GET /api/company/public-info
/// Public branding and booking defaults for the authenticated user's company.
/// Uses Decodable only — this is read-only data.
///
/// Fields are optional because the backend may omit them depending on company setup.
/// `buybackEnabled` needs Bool-or-Int handling (SQLite/D1 may return 0/1).
struct CompanyPublicInfo: Decodable, Sendable {
    let id: String
    let name: String?
    let logoUrl: String?
    let vatNumber: String?
    let termsConditions: String?
    let privacyPolicy: String?
    let customerPortalUrl: String?
    let currencyCode: String?
    let defaultCountryCode: String?
    let buybackEnabled: Bool?

    // No raw values — let .convertFromSnakeCase handle conversion
    private enum CodingKeys: String, CodingKey {
        case id, name, logoUrl, vatNumber, termsConditions, privacyPolicy
        case customerPortalUrl, currencyCode, defaultCountryCode
        case buybackEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        vatNumber = try container.decodeIfPresent(String.self, forKey: .vatNumber)
        termsConditions = try container.decodeIfPresent(String.self, forKey: .termsConditions)
        privacyPolicy = try container.decodeIfPresent(String.self, forKey: .privacyPolicy)
        customerPortalUrl = try container.decodeIfPresent(String.self, forKey: .customerPortalUrl)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
        defaultCountryCode = try container.decodeIfPresent(String.self, forKey: .defaultCountryCode)

        // Handle Bool-or-Int from SQLite
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: .buybackEnabled) {
            buybackEnabled = boolVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .buybackEnabled) {
            buybackEnabled = intVal != 0
        } else {
            buybackEnabled = nil
        }
    }

    // Manual init for sample data
    init(id: String, name: String?, logoUrl: String?, vatNumber: String?, termsConditions: String?, privacyPolicy: String?, customerPortalUrl: String?, currencyCode: String?, defaultCountryCode: String?, buybackEnabled: Bool?) {
        self.id = id
        self.name = name
        self.logoUrl = logoUrl
        self.vatNumber = vatNumber
        self.termsConditions = termsConditions
        self.privacyPolicy = privacyPolicy
        self.customerPortalUrl = customerPortalUrl
        self.currencyCode = currencyCode
        self.defaultCountryCode = defaultCountryCode
        self.buybackEnabled = buybackEnabled
    }
}

extension CompanyPublicInfo {
    static var sample: CompanyPublicInfo {
        CompanyPublicInfo(
            id: "company-1",
            name: "RepairShop Ltd",
            logoUrl: nil,
            vatNumber: "GB123456789",
            termsConditions: "By signing this form you agree...",
            privacyPolicy: "We store your data securely...",
            customerPortalUrl: "https://app.repairminder.net",
            currencyCode: "GBP",
            defaultCountryCode: "GB",
            buybackEnabled: true
        )
    }
}
