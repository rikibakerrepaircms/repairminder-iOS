//
//  DeviceActionInputDecodeTests.swift
//  Repair MinderTests
//
//  Tests that DeviceAction correctly decodes the Worker's action fields:
//  requires_input (array of string field keys), requires_notes (bool),
//  confirmation_message (string), and that DeviceActionRequest encodes
//  collected inputs as top-level sibling keys alongside to_status.
//

import Testing
import Foundation
@testable import Repair_Minder

struct DeviceActionInputDecodeTests {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    // MARK: - Decode: requiresInput

    @Test func decodesRequiresInputAsStringArray() throws {
        let json = """
        {"to_status":"repaired_ready->despatched","label":"Mark Despatched",
         "requires_confirmation":true,
         "requires_input":["tracking_number"]}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.requiresInput == ["tracking_number"])
    }

    @Test func decodesRequiresInputNullAsNil() throws {
        let json = """
        {"to_status":"diagnosing","label":"Start Diagnosis",
         "requires_confirmation":false,"requires_input":null}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.requiresInput == nil)
    }

    @Test func decodesRequiresInputMissingAsNil() throws {
        let json = """
        {"to_status":"diagnosing","label":"Start Diagnosis","requires_confirmation":false}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.requiresInput == nil)
    }

    // MARK: - Decode: requiresNotes / confirmationMessage (reserved fields)

    @Test func decodesRequiresNotesAndConfirmationMessage() throws {
        let json = """
        {"to_status":"collected","label":"Mark Collected",
         "requires_confirmation":true,
         "requires_notes":true,
         "confirmation_message":"Are you sure the customer has collected their device?"}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.requiresNotes == true)
        #expect(action.confirmationMessage == "Are you sure the customer has collected their device?")
    }

    @Test func decodesWithAllFieldsPresent() throws {
        let json = """
        {"to_status":"despatched","label":"Mark Despatched",
         "display_label":"Despatched",
         "requires_confirmation":true,
         "requires_input":["tracking_number"],
         "requires_notes":false,
         "confirmation_message":"Confirm despatch with tracking number."}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.toStatus == "despatched")
        #expect(action.requiresInput == ["tracking_number"])
        #expect(action.requiresNotes == false)
        #expect(action.confirmationMessage == "Confirm despatch with tracking number.")
        #expect(action.needsInputCollection == true)
    }

    // MARK: - needsInputCollection

    @Test func needsInputCollectionFalseForPlainAction() throws {
        let json = """
        {"to_status":"diagnosing","label":"Start Diagnosis",
         "requires_confirmation":false}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.needsInputCollection == false)
    }

    @Test func needsInputCollectionTrueWhenRequiresConfirmation() throws {
        let json = """
        {"to_status":"collected","label":"Mark Collected","requires_confirmation":true}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.needsInputCollection == true)
    }

    @Test func needsInputCollectionTrueWhenRequiresInput() throws {
        let json = """
        {"to_status":"despatched","label":"Mark Despatched",
         "requires_confirmation":false,
         "requires_input":["tracking_number"]}
        """.data(using: .utf8)!
        let action = try decoder().decode(DeviceAction.self, from: json)
        #expect(action.needsInputCollection == true)
    }

    // MARK: - DeviceActionRequest encoding: inputs spread at top level

    @Test func encodesInputsAsTopLevelKeys() throws {
        let req = DeviceActionRequest(
            toStatus: "despatched",
            context: .devicePage,
            inputs: ["tracking_number": "TRK-99"]
        )
        let data = try encoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["to_status"] as? String == "despatched")
        #expect(dict["context"] as? String == "device_page")
        // The tracking_number must be a sibling of to_status, not nested
        #expect(dict["tracking_number"] as? String == "TRK-99")
        #expect(dict["inputs"] == nil)   // must NOT be under an "inputs" key
    }

    @Test func encodesMultipleInputsAsTopLevelKeys() throws {
        let req = DeviceActionRequest(
            toStatus: "awaiting_authorisation",
            inputs: ["quote_items_confirmed": "1", "bank_details": "Account 12345"]
        )
        let data = try encoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["quote_items_confirmed"] as? String == "1")
        #expect(dict["bank_details"] as? String == "Account 12345")
        #expect(dict["inputs"] == nil)
    }

    @Test func encodesNotesWhenPresent() throws {
        let req = DeviceActionRequest(
            toStatus: "repaired_qc",
            notes: "All checks passed.",
            inputs: [:]
        )
        let data = try encoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["notes"] as? String == "All checks passed.")
    }

    @Test func omitsNotesKeyWhenNil() throws {
        let req = DeviceActionRequest(toStatus: "diagnosing", inputs: [:])
        let data = try encoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["notes"] == nil)
    }

    // MARK: - Full actions response with requires_input

    @Test func decodesFullActionsResponseWithRequiresInput() throws {
        let json = """
        {"current_status":"repaired_ready","workflow_type":"repair","available_actions":[
          {"to_status":"collected","label":"Mark Collected",
           "requires_confirmation":true,"requires_input":null},
          {"to_status":"despatched","label":"Mark Despatched",
           "requires_confirmation":true,"requires_input":["tracking_number"]}
        ]}
        """.data(using: .utf8)!
        let response = try decoder().decode(DeviceActionsResponse.self, from: json)
        #expect(response.availableActions.count == 2)
        let collected = response.availableActions[0]
        let despatched = response.availableActions[1]
        #expect(collected.requiresInput == nil)
        #expect(collected.needsInputCollection == true)  // requiresConfirmation=true
        #expect(despatched.requiresInput == ["tracking_number"])
        #expect(despatched.needsInputCollection == true)
    }
}
