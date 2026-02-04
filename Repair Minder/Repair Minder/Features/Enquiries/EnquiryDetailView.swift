//
//  EnquiryDetailView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryDetailView: View {
    let enquiryId: String
    @StateObject private var viewModel: EnquiryDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConvertSheet = false
    @State private var showWorkflowSheet = false
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool

    init(enquiryId: String) {
        self.enquiryId = enquiryId
        _viewModel = StateObject(wrappedValue: EnquiryDetailViewModel(enquiryId: enquiryId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if viewModel.isLoading && viewModel.enquiry == nil {
                LoadingView(message: "Loading enquiry...")
            } else if let enquiry = viewModel.enquiry {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Enquiry Header Card
                            EnquiryHeaderCard(enquiry: enquiry)

                            // Device Info Card
                            EnquiryDeviceInfoCard(enquiry: enquiry)

                            // Issue Description
                            IssueDescriptionCard(description: enquiry.issueDescription)

                            // Converted Order Link
                            if enquiry.status == .converted, let orderId = enquiry.convertedOrderId {
                                ConvertedOrderBanner(orderId: orderId)
                            }

                            // Conversation Thread
                            ConversationThread(
                                messages: viewModel.messages,
                                scrollProxy: proxy
                            )
                        }
                        .padding()
                    }
                }

                // Quick Reply Bar (only for active enquiries)
                if enquiry.status.isActive {
                    QuickReplyBar(
                        text: $replyText,
                        isFocused: $isReplyFocused,
                        onSend: {
                            Task {
                                await viewModel.sendReply(replyText)
                                replyText = ""
                            }
                        },
                        onGenerateAI: {
                            Task {
                                if let generatedText = await viewModel.generateAIReply() {
                                    replyText = generatedText
                                }
                            }
                        },
                        onSelectWorkflow: {
                            showWorkflowSheet = true
                        },
                        templates: viewModel.replyTemplates,
                        workflows: viewModel.workflows,
                        isSending: viewModel.isSending,
                        isGeneratingAI: viewModel.isGeneratingAI
                    )
                }
            } else {
                ErrorView(
                    message: viewModel.error?.localizedDescription ?? "Failed to load enquiry",
                    retryAction: {
                        Task { await viewModel.load() }
                    }
                )
            }
        }
        .navigationTitle("Enquiry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showConvertSheet) {
            if let enquiry = viewModel.enquiry {
                ConvertToOrderSheet(
                    enquiry: enquiry,
                    onConvert: { orderData in
                        Task {
                            await viewModel.convertToOrder(orderData)
                            showConvertSheet = false
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showWorkflowSheet) {
            WorkflowSelectionSheet(
                workflows: viewModel.workflows,
                onSelect: { workflow in
                    Task {
                        let success = await viewModel.executeWorkflow(workflow)
                        if success {
                            showWorkflowSheet = false
                        }
                    }
                },
                isExecuting: viewModel.isExecutingWorkflow
            )
        }
        .task {
            await viewModel.load()
            viewModel.markAsRead()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let enquiry = viewModel.enquiry, enquiry.status != .converted {
                    Button {
                        showConvertSheet = true
                    } label: {
                        Label("Convert to Order", systemImage: "doc.badge.plus")
                    }
                }

                if viewModel.enquiry?.status != .spam {
                    Button {
                        Task { await viewModel.markAsSpam() }
                    } label: {
                        Label("Mark as Spam", systemImage: "xmark.bin")
                    }
                }

                if viewModel.enquiry?.status != .archived {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.archive()
                            dismiss()
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }

        // Convert to Order button (prominent) for active enquiries
        if let enquiry = viewModel.enquiry, enquiry.status.isActive, enquiry.status != .converted {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showConvertSheet = true
                } label: {
                    Label("Create Order", systemImage: "plus.circle.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Converted Order Banner
struct ConvertedOrderBanner: View {
    let orderId: String
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.navigate(to: .orderDetail(id: orderId))
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Converted to Order")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Tap to view order details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        EnquiryDetailView(enquiryId: "preview-1")
    }
    .environment(AppRouter())
}
