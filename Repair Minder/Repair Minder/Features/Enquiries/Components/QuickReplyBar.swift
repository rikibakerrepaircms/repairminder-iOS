//
//  QuickReplyBar.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct QuickReplyBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let templates: [ReplyTemplate]
    let isSending: Bool

    @State private var showTemplates = false

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        onSend: @escaping () -> Void,
        templates: [ReplyTemplate],
        isSending: Bool = false
    ) {
        self._text = text
        self.isFocused = isFocused
        self.onSend = onSend
        self.templates = templates
        self.isSending = isSending
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Quick templates (expandable)
            if showTemplates {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates) { template in
                            Button {
                                text = template.content
                                showTemplates = false
                            } label: {
                                Text(template.name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.secondarySystemBackground))
            }

            // Input row
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showTemplates.toggle()
                    }
                } label: {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                        .foregroundStyle(showTemplates ? Color.accentColor : Color.secondary)
                }

                TextField("Type a reply...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused(isFocused)

                Button {
                    onSend()
                } label: {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.accentColor)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var isFocused: Bool

    QuickReplyBar(
        text: $text,
        isFocused: $isFocused,
        onSend: { print("Sent: \(text)") },
        templates: [
            ReplyTemplate(id: "1", name: "Greeting", content: "Thank you for contacting us!"),
            ReplyTemplate(id: "2", name: "Quote", content: "The repair will cost approximately..."),
            ReplyTemplate(id: "3", name: "Book In", content: "Please bring your device to our shop.")
        ]
    )
}
