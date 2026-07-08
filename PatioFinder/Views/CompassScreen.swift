import SwiftUI
import CoreLocation
import UIKit

/// The primary "point me to the patio" screen.
struct CompassScreen: View {
    @ObservedObject var viewModel: PatioViewModel
    @ObservedObject var location: LocationService

    @State private var showingList = false
    @State private var showingMap = false
    @State private var dragOffset: CGFloat = 0

    private let alignmentHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch viewModel.loadState {
            case .idle, .loading:
                loadingView
            case .error(let message):
                messageView(title: "Something went wrong",
                            subtitle: message,
                            systemImage: "exclamationmark.triangle")
            case .empty:
                messageView(title: "No patios nearby",
                            subtitle: "Try again from somewhere else, or add spots to the seed list.",
                            systemImage: "fork.knife")
            case .loaded:
                if isPermissionDenied {
                    permissionDeniedView
                } else {
                    compassContent
                }
            }
        }
        .onAppear {
            viewModel.start()
            alignmentHaptic.prepare()
        }
        .onChange(of: viewModel.isAligned) { _, aligned in
            if aligned { alignmentHaptic.impactOccurred() }
        }
        .sheet(isPresented: $showingList) {
            PatioListView(viewModel: viewModel, location: location)
        }
        .sheet(isPresented: $showingMap) {
            if let patio = viewModel.selectedPatio {
                PatioMapView(patio: patio, userLocation: location.location?.coordinate)
            }
        }
    }

    // MARK: - Main content

    private var compassContent: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 8)

            ArrowView(
                rotation: viewModel.arrowRotationDegrees ?? 0,
                isAligned: viewModel.isAligned,
                isActive: viewModel.hasHeading && viewModel.arrowRotationDegrees != nil
            )
            .offset(x: dragOffset)
            .gesture(cycleGesture)

            distanceBlock

            Spacer(minLength: 8)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(positionLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accentDeep)
                .textCase(.uppercase)
                .kerning(0.8)

            Text(viewModel.selectedPatio?.name ?? "—")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let rating = viewModel.selectedPatio?.rating {
                Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) { toolbarButtons }
    }

    private var toolbarButtons: some View {
        HStack(spacing: 14) {
            iconButton("map") { showingMap = true }
            iconButton("list.bullet") { showingList = true }
        }
    }

    private func iconButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.12), in: Circle())
        }
        .accessibilityLabel(system == "map" ? "Show map" : "Show patio list")
    }

    private var distanceBlock: some View {
        VStack(spacing: 4) {
            Text(viewModel.distanceText ?? "—")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.distanceText)

            if let address = viewModel.selectedPatio?.address {
                Text(address)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
            }

            if !viewModel.hasHeading {
                Label("Move your phone in a figure 8 to calibrate the compass",
                      systemImage: "safari")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            pageDots

            HStack(spacing: 12) {
                Image(systemName: "chevron.left")
                Text("Swipe to change patio")
                Image(systemName: "chevron.right")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.secondaryText)

            if !viewModel.isShowingNearest {
                Button {
                    withAnimation { viewModel.resetToNearest() }
                } label: {
                    Label("Back to nearest", systemImage: "location.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }

            if viewModel.usingSeedData {
                Text("Showing sample patios")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.bottom, 8)
    }

    private var pageDots: some View {
        let count = min(viewModel.patios.count, 7)
        return HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == min(viewModel.selectedIndex, count - 1)
                          ? Theme.accent : Theme.secondaryText.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .opacity(viewModel.patios.count > 1 ? 1 : 0)
    }

    // MARK: - Gestures

    private var cycleGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Only track mostly-horizontal drags.
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width * 0.4
                }
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = 0
                }
                guard horizontal, abs(value.translation.width) > 50 else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if value.translation.width < 0 {
                        viewModel.selectNext()
                    } else {
                        viewModel.selectPrevious()
                    }
                }
            }
    }

    // MARK: - Auxiliary views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(Theme.accent)
            Text("Finding patios near you…")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func messageView(title: String, subtitle: String, systemImage: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(subtitle)
        } actions: {
            Button("Try Again") { viewModel.refresh() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Location needed", systemImage: "location.slash")
        } description: {
            Text("PatioFinder needs your location to point you to the nearest patio. Enable it in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
    }

    // MARK: - Derived

    private var isPermissionDenied: Bool {
        location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }

    private var positionLabel: String {
        if viewModel.isShowingNearest { return "Nearest Patio" }
        let n = viewModel.selectedIndex + 1
        return "Patio \(n) of \(viewModel.patios.count)"
    }
}
