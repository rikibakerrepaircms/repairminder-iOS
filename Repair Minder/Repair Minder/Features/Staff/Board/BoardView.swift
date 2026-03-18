//
//  BoardView.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Board View

/// Main board container with horizontally scrollable status columns.
/// Adapts layout: iPhone snaps one column at a time, iPad shows multiple, Mac uses fixed 280px.
/// Manages drag state and shows drag overlay.
struct BoardView: View {
    let viewModel: BoardViewModel
    let onDeviceTap: (BoardDeviceItem) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var dragState = BoardDragState()
    @State private var showListBuilder = false
    @State private var dropSucceeded = false
    @State private var dropFailed = false
    @Namespace private var sheetNamespace

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// Column width for non-compact layouts
    private var columnWidth: CGFloat {
        #if os(macOS)
        280
        #else
        260 // iPad: fit 3-4 columns
        #endif
    }

    /// Timeline column width
    private var timelineWidth: CGFloat { 300 }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.columnData.isEmpty {
                loadingSkeleton
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.needsSetup {
                setupPrompt
            } else {
                boardContent
            }
        }
    }

    // MARK: - Board Content

    /// Regular (non-pinned) columns for display
    private var regularColumnData: [BoardColumnData] {
        viewModel.columnData.filter { $0.column.columnType != "pinned" }
    }

    private var boardContent: some View {
        VStack(spacing: 0) {
            // Engineer legend + settings button
            if !viewModel.engineers.isEmpty || !viewModel.columnData.isEmpty {
                HStack {
                    EngineerColorLegend(engineers: viewModel.engineers)
                    Spacer()
                    settingsButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Board columns (timeline + regular)
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    ConditionalGlassContainer(spacing: 12) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        // Timeline column (first, when enabled)
                        if viewModel.timelineColumn != nil {
                            timelineColumnView
                        }

                        // Regular columns (skip pinned — handled above)
                        ForEach(regularColumnData) { column in
                            if isCompact {
                                BoardColumnView(
                                    columnData: column,
                                    dragState: dragState,
                                    onDeviceTap: onDeviceTap,
                                    onDragStart: handleDragStart
                                )
                                .containerRelativeFrame(.horizontal) { width, _ in
                                    width - 40
                                }
                            } else {
                                BoardColumnView(
                                    columnData: column,
                                    dragState: dragState,
                                    onDeviceTap: onDeviceTap,
                                    onDragStart: handleDragStart
                                )
                                .frame(width: columnWidth)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, isCompact ? 20 : 16)
                    .padding(.vertical, 12)
                    } // ConditionalGlassContainer
                }
                .scrollTargetBehavior(.viewAligned)
                .background(Color.platformGroupedBackground)

                // Drag overlay
                if dragState.isDragging, let device = dragState.draggedDevice {
                    BoardDragOverlayCard(device: device, swingAngle: dragState.swingAngle)
                        .position(
                            x: dragState.dragStartLocation.x + dragState.dragOffset.width,
                            y: dragState.dragStartLocation.y + dragState.dragOffset.height
                        )
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "boardContainer")
            .gesture(dragState.isDragging ? boardDragGesture : nil)
            .sensoryFeedback(.success, trigger: dropSucceeded)
            .sensoryFeedback(.error, trigger: dropFailed)
        }
        .sheet(isPresented: $showListBuilder) {
            listBuilderSheetContent
        }
    }

    // MARK: - Timeline Column

    @ViewBuilder
    private var timelineColumnView: some View {
        let timeline = TimelineColumn(
            devices: viewModel.allDevices,
            scheduleItems: viewModel.scheduleItems,
            onDeviceTap: onDeviceTap,
            onDurationChange: { itemId, duration in
                Task { await viewModel.updateScheduleDuration(itemId: itemId, duration: duration) }
            },
            onStartTimeChange: { itemId, newStart, newDuration in
                Task { await viewModel.updateScheduleStartTime(itemId: itemId, startMinutes: newStart, duration: newDuration) }
            },
            newlyScheduledId: viewModel.newlyScheduledId
        )

        if isCompact {
            timeline
                .containerRelativeFrame(.horizontal) { width, _ in
                    width - 40
                }
        } else {
            timeline
                .frame(width: timelineWidth)
        }
    }

    // MARK: - Settings Button (Sheet Morphing on iOS 18+)

    @ViewBuilder
    private var settingsButton: some View {
        let button = Button {
            showListBuilder = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.body)
                .foregroundStyle(.secondary)
        }

        if #available(iOS 18, macOS 15, *) {
            button.matchedTransitionSource(id: "listBuilder", in: sheetNamespace)
        } else {
            button
        }
    }

    @ViewBuilder
    private var listBuilderSheetContent: some View {
        if #available(iOS 18, macOS 15, *) {
            ListBuilderSheet(viewModel: viewModel)
                .navigationTransition(.zoom(sourceID: "listBuilder", in: sheetNamespace))
        } else {
            ListBuilderSheet(viewModel: viewModel)
        }
    }

    // MARK: - Drag Handling

    private func handleDragStart(device: BoardDeviceItem, columnId: String, location: CGPoint) {
        // Start position will be updated on first drag gesture change
        dragState.startDrag(device: device, fromColumnId: columnId, startLocation: .zero)
    }

    private var boardDragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                // On first change, set the start location
                if dragState.dragStartLocation == .zero {
                    dragState.dragStartLocation = value.startLocation
                }
                dragState.updateDrag(
                    translation: value.translation,
                    currentLocation: value.location
                )
            }
            .onEnded { _ in
                guard let sourceColumnId = dragState.sourceColumnId,
                      let device = dragState.draggedDevice else {
                    dragState.cancelDrag()
                    return
                }

                if let targetColumnId = dragState.endDrag() {
                    // Execute drop
                    Task {
                        let success = await viewModel.moveDevice(
                            device,
                            fromColumnId: sourceColumnId,
                            toColumnId: targetColumnId
                        )
                        if success {
                            dropSucceeded.toggle()
                        } else {
                            dropFailed.toggle()
                        }
                    }
                } else {
                    // Dropped outside any column — cancel
                    dragState.cancelDrag()
                }
            }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 0) {
                        // Header skeleton
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 14)
                            Spacer()
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 30, height: 20)
                        }
                        .padding(12)

                        Divider()

                        // Card skeletons
                        VStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 72)
                            }
                        }
                        .padding(8)

                        Spacer()
                    }
                    .containerRelativeFrame(.horizontal) { width, _ in
                        isCompact ? width - 40 : columnWidth
                    }
                    .background(Color.platformGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, isCompact ? 20 : 16)
            .padding(.vertical, 12)
        }
        .background(Color.platformGroupedBackground)
        .redacted(reason: .placeholder)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Board Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }

    // MARK: - Setup Prompt (User Scope)

    private var setupPrompt: some View {
        ContentUnavailableView {
            Label("Set Up Your Board", systemImage: "rectangle.3.group")
        } description: {
            Text("Copy the company board layout to get started with your personal board.")
        } actions: {
            Button("Copy Company Board") {
                Task {
                    await viewModel.seedFromCompany()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
