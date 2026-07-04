//
//  BuybackListingModels.swift
//  Repair Minder
//
//  AI marketplace listing generation (async job + poll) for buyback items.
//  POST /api/buyback/:id/generate-listing starts (or reports) a job; GET on
//  the same path returns the current job state. The generated listing
//  fields themselves are persisted server-side and come back on the regular
//  GET /api/buyback/:id detail endpoint (see `BuybackDetail`).
//

import Foundation

/// Mirrors the server's `status` values for a listing-generation job.
/// `idle`/`running` mean "keep polling"; `done`/`error` are terminal.
enum ListingJobStatus: String, Decodable, Sendable {
    case idle
    case running
    case done
    case error
}

/// Response body for POST /api/buyback/:id/generate-listing (202 new job, or
/// 200 if a job was already running).
struct ListingJobStart: Decodable, Sendable {
    let jobId: String?
    let status: String?
    let startedAt: String?
    let alreadyRunning: Bool?
}

/// Response body for GET /api/buyback/:id/generate-listing (always 200).
/// `result` is intentionally not modelled — on `status == "done"` the caller
/// refetches the buyback detail instead of decoding the job payload.
struct ListingJobState: Decodable, Sendable {
    let status: String
    let jobId: String?
    let startedAt: String?
    let completedAt: String?
    let error: String?
    let errorStatus: Int?
}
