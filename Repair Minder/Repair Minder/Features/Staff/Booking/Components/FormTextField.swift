//
//  FormTextField.swift
//  Repair Minder
//

import SwiftUI

struct FormTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var isRequired: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.6 : 1)
        }
    }
}

#Preview {
    VStack {
        FormTextField(
            label: "Name",
            text: .constant("John"),
            placeholder: "Enter name",
            isRequired: true
        )
    }
    .padding()
}
