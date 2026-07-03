import Foundation

// MARK: - Supplier orders (book-in)

/// A supplier order. List rows add `line_count`; detail adds a nested `lines` array.
struct SupplierOrder: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var companyId: String?
    var orderNumber: String?
    var supplierName: String
    var supplierOrderReference: String?
    var status: String              // pending | ordered | partial | received | cancelled
    var orderDate: String?
    var expectedDate: String?
    var receivedDate: String?
    var totalItems: Int?
    var totalReceived: Int?
    var totalCost: Double?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?
    var invoiceFileKey: String?
    var lineCount: Int?             // list only
    var lines: [SupplierOrderLine]?  // detail only

    var remainingCount: Int { (totalItems ?? 0) - (totalReceived ?? 0) }
}

struct SupplierOrderLine: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var supplierOrderId: String?
    var productTypeId: String?
    var name: String
    var sku: String?
    var category: String?
    var quantityOrdered: Int
    var quantityReceived: Int
    var unitCost: Double?           // NOT NULL default 0 server-side; optional for decode safety
    var lineTotal: Double?
    var locationId: String?
    var subLocationId: String?
    var productTypeName: String?    // detail join
    var productKind: String?        // detail join

    var isFullyReceived: Bool { quantityReceived >= quantityOrdered }
    var remaining: Int { max(0, quantityOrdered - quantityReceived) }
}

// MARK: - Request bodies

struct CreateSupplierOrderRequest: Encodable {
    var supplierName: String
    var supplierOrderReference: String? = nil
    var orderDate: String? = nil
    var expectedDate: String? = nil
    var notes: String? = nil
    var invoiceFileKey: String? = nil
    var lines: [SupplierOrderLineRequest]? = nil
}

struct SupplierOrderLineRequest: Encodable, Equatable {
    var productTypeId: String? = nil
    var name: String
    var sku: String? = nil
    var category: String? = nil
    var quantityOrdered: Int? = nil
    var unitCost: Double? = nil
    var locationId: String? = nil
    var subLocationId: String? = nil
}

struct UpdateSupplierOrderRequest: Encodable {
    var status: String? = nil
    var supplierName: String? = nil
    var supplierOrderReference: String? = nil
    var orderDate: String? = nil
    var expectedDate: String? = nil
    var notes: String? = nil
    var invoiceFileKey: String? = nil
}

struct ReceiveItemsRequest: Encodable {
    var items: [ReceiveItemInput]
}

struct ReceiveItemInput: Encodable, Equatable {
    var lineId: String
    var quantity: Int? = nil
    var serialNumbers: [String]? = nil
    var unitCost: Double? = nil
    var warrantyMonths: Int? = nil
    var conditionGrade: String? = nil
    var isOem: Int? = nil
    var isRefurbished: Int? = nil
    var locationId: String? = nil
    var subLocationId: String? = nil
}

struct ReceiveItemsResult: Decodable, Equatable, Sendable {
    var order: SupplierOrder
    var createdAssets: [Asset]
    var assetsCreatedCount: Int
}

// MARK: - Supplier datalist (GET /api/supplier-mappings/suppliers)

struct SupplierNameOption: Decodable, Identifiable, Equatable, Sendable {
    let supplierName: String
    var mappingCount: Int?
    var totalUsage: Int?
    var lastUsed: String?
    var id: String { supplierName }
}

// MARK: - Invoice extraction (POST /api/supplier-orders/extract-invoice)

/// Whole-body response (decoded via `uploadMultipartFull` to keep `invoice_file_key`).
struct ExtractInvoiceResponse: Decodable, Equatable, Sendable {
    var success: Bool
    var data: ExtractedInvoice
    var invoiceFileKey: String?
    var fileType: String?
}

struct ExtractedInvoice: Decodable, Equatable, Sendable {
    var supplierName: String?
    var supplierVat: String?
    var invoiceReference: String?
    var invoiceDate: String?
    var lineItems: [ExtractedInvoiceLine]
    var subtotal: Double?
    var vat: Double?
    var total: Double?
    var confidence: Double?
    var extractionMethod: String?
}

/// Base fields + optional mapping enrichment (variable per provider/match).
struct ExtractedInvoiceLine: Decodable, Equatable, Sendable, Identifiable {
    var name: String
    var sku: String?
    var quantity: Int?
    var unitCost: Double?
    var category: String?
    var manufacturer: String?
    var compatibleModel: String?
    // Enrichment (optional)
    var mappingFound: Bool?
    var productTypeId: String?
    var mappedProductName: String?
    var mappedProductSku: String?
    var mappedProductCategory: String?
    var needsMapping: Bool?
    var supplierName: String?
    var supplierSku: String?

    var id: String { name + (sku ?? "") }
    var quantityValue: Int { quantity ?? 1 }
    var unitCostValue: Double { unitCost ?? 0 }
}

// MARK: - CSV import (POST /api/assets/import)

struct AssetImportResponse: Decodable, Equatable, Sendable {
    var success: Bool
    var message: String?
    var data: AssetImportCounts?
}

struct AssetImportCounts: Decodable, Equatable, Sendable {
    var imported: Int
    var createdProductTypes: Int?
    var createdCategories: Int?
    var createdManufacturers: Int?
}

/// The 400 `validation_failed` body (decoded from the raw error body).
struct AssetImportValidationBody: Decodable, Equatable, Sendable {
    var error: String?
    var message: String?
    var errors: [AssetImportRowError]?
    var totalErrors: Int?
}

struct AssetImportRowError: Decodable, Equatable, Sendable, Identifiable {
    var row: Int?
    var sku: String?
    var error: String?
    var message: String?
    var id: String { "\(row ?? -1)-\(sku ?? "")-\(error ?? message ?? "")" }

    var display: String {
        let prefix = row.map { "Row \($0): " } ?? ""
        return prefix + (error ?? message ?? "Invalid")
    }
}
