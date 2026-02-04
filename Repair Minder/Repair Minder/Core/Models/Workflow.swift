//
//  Workflow.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

/// A workflow (macro) that can be executed on enquiries
struct Workflow: Identifiable, Decodable, Sendable {
    let id: String
    let name: String
    let description: String?
    let initialSubject: String?
    let initialContent: String
    let isActive: Bool
    let stageCount: Int?
    let stages: [WorkflowStage]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case initialSubject = "initial_subject"
        case initialContent = "initial_content"
        case isActive = "is_active"
        case stageCount = "stage_count"
        case stages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        initialSubject = try container.decodeIfPresent(String.self, forKey: .initialSubject)
        initialContent = try container.decodeIfPresent(String.self, forKey: .initialContent) ?? ""
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        stageCount = try container.decodeIfPresent(Int.self, forKey: .stageCount)
        stages = try container.decodeIfPresent([WorkflowStage].self, forKey: .stages)
    }
}

/// A follow-up stage in a workflow
struct WorkflowStage: Identifiable, Decodable, Sendable {
    let id: String
    let stageNumber: Int
    let delayMinutes: Int
    let subject: String?
    let content: String

    enum CodingKeys: String, CodingKey {
        case id
        case stageNumber = "stage_number"
        case delayMinutes = "delay_minutes"
        case subject
        case content
    }

    var delayDescription: String {
        if delayMinutes >= 1440 {
            let days = delayMinutes / 1440
            return "\(days) day\(days == 1 ? "" : "s") later"
        } else if delayMinutes >= 60 {
            let hours = delayMinutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") later"
        } else {
            return "\(delayMinutes) minute\(delayMinutes == 1 ? "" : "s") later"
        }
    }
}

/// Response from executing a workflow
struct WorkflowExecutionResponse: Decodable {
    let success: Bool
    let executionId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case executionId = "execution_id"
        case error
    }
}

/// Response from generating an AI reply
struct AIReplyResponse: Decodable {
    let text: String
    let usage: AIUsage?
    let model: String?
    let provider: String?
}

struct AIUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cost: Double?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cost
    }
}
