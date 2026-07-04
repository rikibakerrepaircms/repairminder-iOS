import Foundation

// MARK: - Local (UI-only) cart state

struct KioskSelectedAsset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let assetTag: String?
    let cost: Double?
    let serialNumber: String?
    let locationName: String?
    let subLocation: String?
}

struct KioskCartItem: Identifiable, Equatable, Sendable {
    let id: String                 // local UUID, never sent to the API
    var productTypeId: String?
    var description: String
    var quantity: Int
    var unitPrice: Double
    var vatRate: Double
    var itemType: String
    var discountPercent: Double?
    var discountAmount: Double?
    var discountReason: String?
    var productSku: String?
    var selectedAssets: [KioskSelectedAsset]

    init(id: String = UUID().uuidString,
         productTypeId: String? = nil,
         description: String,
         quantity: Int = 1,
         unitPrice: Double,
         vatRate: Double = 20,
         itemType: String = "accessory",
         discountPercent: Double? = nil,
         discountAmount: Double? = nil,
         discountReason: String? = nil,
         productSku: String? = nil,
         selectedAssets: [KioskSelectedAsset] = []) {
        self.id = id
        self.productTypeId = productTypeId
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.vatRate = vatRate
        self.itemType = itemType
        self.discountPercent = discountPercent
        self.discountAmount = discountAmount
        self.discountReason = discountReason
        self.productSku = productSku
        self.selectedAssets = selectedAssets
    }
}

// MARK: - Request bodies (encoded with .convertToSnakeCase; nil omitted)

struct KioskOrderItemRequest: Encodable {
    let productTypeId: String?
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let itemType: String
    let discountPercent: Double?
    let discountAmount: Double?
    let discountReason: String?
    let assetIds: [String]
}

struct KioskPaymentRequest: Encodable {
    let amount: Double
    let paymentMethod: String
    let notes: String?
}

struct KioskOrderRequest: Encodable {
    let clientId: String?
    let clientEmail: String?
    let clientFirstName: String?
    let clientLastName: String?
    let clientPhone: String?
    let guestCheckout: Bool
    let items: [KioskOrderItemRequest]
    let globalDiscountPercent: Double?
    let globalDiscountAmount: Double?
    let globalDiscountReason: String?
    let payment: KioskPaymentRequest?
    let locationId: String?
}

// MARK: - Response

struct KioskOrderResponse: Decodable, Sendable {
    let id: String
    let orderNumber: Int
    let ticketId: String
    let client: KioskClient
    let items: [KioskResponseItem]
    let totals: KioskResponseTotals
    let payment: KioskResponsePayment?
    let globalDiscountPercent: Double?
    let globalDiscountAmount: Double?
    let globalDiscountReason: String?
    let company: KioskCompany?
    let location: KioskLocation?
    let dates: KioskDates
}

struct KioskClient: Decodable, Sendable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
}

struct KioskResponseItem: Decodable, Identifiable, Sendable {
    let id: String
    let itemType: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let lineTotal: Double
    let vatAmount: Double
    let lineTotalIncVat: Double
    let discountPercent: Double?
    let discountAmount: Double?
    let discountReason: String?
    let productTypeId: String?
    let productSku: String?
}

struct KioskResponseTotals: Decodable, Sendable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
    let discountTotal: Double
    let globalDiscount: Double
    let amountPaid: Double
    let balanceDue: Double
}

struct KioskResponsePayment: Decodable, Sendable {
    let id: String
    let amount: Double
    let paymentMethod: String
    let paymentDate: String
}

struct KioskCompany: Decodable, Sendable {
    let name: String?
    let vatNumber: String?
    let email: String?
    let phone: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?
    let logoUrl: String?
    let currencyCode: String?
}

struct KioskLocation: Decodable, Sendable {
    let id: String?
    let name: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let phone: String?
    let email: String?
}

struct KioskDates: Decodable, Sendable {
    let createdAt: String
}

// MARK: - Available assets (GET /api/kiosk/available-assets)

struct KioskAvailableAsset: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let assetTag: String?
    let cost: Double?
    let serialNumber: String?
    let locationName: String?
    let subLocation: String?
}
