//
//  String+Extensions.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

extension String {
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return self.range(of: emailRegex, options: .regularExpression) != nil
    }

    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }

    var isBlank: Bool {
        self.trimmed.isEmpty
    }

    var nilIfEmpty: String? {
        self.isBlank ? nil : self
    }
}
