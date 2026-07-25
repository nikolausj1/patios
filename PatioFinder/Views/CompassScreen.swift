import SwiftUI
import CoreLocation
import MapKit
import UIKit

/// The primary "point me to the patio" screen.
struct CompassScreen: View {
    @ObservedObject var viewModel: PatioViewModel
    @ObservedObject var location: LocationService
    @ObservedObject var weather: WeatherGlance

    @State private var showingList = false
    @State private var dragOffset: CGFloat = 0
    @State private var slidingToNext = true   // direction of the last cycle, for the carousel transition

    @AppStorage("prefersDarkMode") private var prefersDarkMode = true

    private let alignmentHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let cycleHaptic = UISelectionFeedbackGenerator()

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

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
    }

    // MARK: - Main content

    private var compassContent: some View {
        VStack(spacing: 0) {
            header

            patioCard
                .frame(maxHeight: .infinity)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        // Swipe anywhere on the screen — not just on the arrow.
        .contentShape(Rectangle())
        .gesture(cycleGesture)
    }

    /// Everything specific to the selected patio — name, arrow, distance —
    /// slides off-screen as one unit when cycling, carousel-style.
    private var patioCard: some View {
        let slide = UIScreen.main.bounds.width
        return ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 12)

                nameBlock

                Spacer(minLength: 16)

                ArrowView(
                    rotation: viewModel.arrowRotationDegrees ?? 0,
                    isAligned: viewModel.isAligned,
                    isActive: viewModel.hasHeading && viewModel.arrowRotationDegrees != nil
                )

                distanceBlock

                Spacer(minLength: 12)
            }
            .offset(x: dragOffset)
            .id(viewModel.selectedIndex)
            .transition(.asymmetric(
                insertion: .offset(x: slidingToNext ? slide : -slide),
                removal: .offset(x: slidingToNext ? -slide : slide)))
        }
    }

    private var header: some View {
        Text(positionLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accentDeep)
            .textCase(.uppercase)
            .kerning(0.8)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) { appearanceToggleButton }
            .overlay(alignment: .trailing) { toolbarButtons }
    }

    private var nameBlock: some View {
        VStack(spacing: 6) {
            Text(viewModel.selectedPatio?.name ?? "—")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if viewModel.selectedPatio?.rating != nil || viewModel.selectedPatio?.openNow != nil {
                HStack(spacing: 10) {
                    ratingView
                    openNowBadge
                }
            }

            if let p = viewModel.selectedPatio, p.servesAlcohol {
                drinkGlyphs(for: p)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Beer / wine / cocktail markers, tinted to match the star rating (grey).
    /// iOS 17 has no cocktail SF Symbol, so cocktails use a small drawn martini.
    @ViewBuilder
    private func drinkGlyphs(for p: Patio) -> some View {
        HStack(spacing: 7) {
            if p.servesBeer == true {
                Image(systemName: "mug.fill").font(.footnote)
            }
            if p.servesWine == true {
                Image(systemName: "wineglass.fill").font(.footnote)
            }
            if p.servesCocktails == true {
                MartiniGlass().frame(width: 11, height: 13)
            }
        }
        .foregroundStyle(Theme.secondaryText)   // same greyish tint as the star
    }

    /// The Google review score (display only).
    @ViewBuilder
    private var ratingView: some View {
        if let rating = viewModel.selectedPatio?.rating {
            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var openNowBadge: some View {
        if let openNow = viewModel.selectedPatio?.openNow {
            HStack(spacing: 4) {
                Circle()
                    .fill(openNow ? .green : .red)
                    .frame(width: 7, height: 7)
                Text(openNow ? "Open now" : "Closed")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
        }
    }

    private var toolbarButtons: some View {
        iconButton("list.bullet") { showingList = true }
    }

    private var appearanceToggleButton: some View {
        Button {
            withAnimation { prefersDarkMode.toggle() }
        } label: {
            Image(systemName: prefersDarkMode ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
        }
        .accessibilityLabel("Toggle appearance")
    }

    private func iconButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
        }
        .accessibilityLabel("Show patio list")
    }

    private var distanceBlock: some View {
        VStack(spacing: 4) {
            Text(viewModel.distanceText ?? "—")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.distanceText)

            if let eta = viewModel.walkingETAText {
                Label(eta, systemImage: "figure.walk")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            }

            weatherGlanceView

            if let address = viewModel.selectedPatio?.displayAddress {
                // Invisible button: tapping the address (or its map icon)
                // opens walking directions.
                Button(action: openSelectedPatioInMaps) {
                    HStack(spacing: 5) {
                        Text(address)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Image(systemName: "map.fill")
                            .font(.caption)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens walking directions in Maps")
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

    @ViewBuilder
    private var weatherGlanceView: some View {
        if let summary = weather.summaryText {
            VStack(spacing: 2) {
                if weather.isGreatPatioWeather {
                    Label("\(summary) — great patio weather", systemImage: "sun.max.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                    Text("\u{F8FF} Weather")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText.opacity(0.7))
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            pageDots

            Text("Swipe to change patio")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .opacity(viewModel.patios.count > 1 ? 1 : 0)

            if !viewModel.isShowingNearest {
                Button {
                    withAnimation { viewModel.resetToNearest() }
                } label: {
                    Label("Back to nearest", systemImage: "location.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accent)
            }

            if viewModel.usingSeedData {
                Text("Showing sample patios")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }

            if !viewModel.usingSeedData {
                Text("Patio data: Google")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
            }
        }
        .padding(.bottom, 8)
    }

    private var pageDots: some View {
        let count = min(viewModel.patios.count, 7)
        return HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                let isCurrent = i == min(viewModel.selectedIndex, count - 1)
                Capsule()
                    .fill(isCurrent ? Theme.accent : Theme.secondaryText.opacity(0.3))
                    .frame(width: isCurrent ? 20 : 7, height: 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8),
                               value: viewModel.selectedIndex)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(viewModel.patios.count > 1 ? 1 : 0)
    }

    /// Walking directions to the selected patio, named so Maps shows the
    /// restaurant instead of "Dropped Pin".
    private func openSelectedPatioInMaps() {
        guard let patio = viewModel.selectedPatio else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: patio.coordinate))
        mapItem.name = patio.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // MARK: - Gestures

    private var cycleGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                // Only track mostly-horizontal drags.
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width * 0.5
                }
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                // Accept either a modest drag or a quick flick.
                let travel = value.translation.width
                let flick = value.predictedEndTranslation.width
                guard horizontal, abs(travel) > 30 || abs(flick) > 80 else {
                    // Not enough: spring the card back to center.
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                    return
                }
                // cycle() resets dragOffset inside the slide animation.
                cycle(next: (abs(travel) > 30 ? travel : flick) < 0)
            }
    }

    private func cycle(next: Bool) {
        guard viewModel.patios.count > 1 else { return }
        cycleHaptic.selectionChanged()
        slidingToNext = next
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            dragOffset = 0
            if next { viewModel.selectNext() } else { viewModel.selectPrevious() }
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

/// A tiny filled martini glass — iOS 17 has no cocktail SF Symbol, so we draw
/// one to sit alongside `mug.fill` / `wineglass.fill`. As a `Shape` it fills
/// with the inherited foreground style, so it tints with the others.
struct MartiniGlass: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        // Bowl: a wide, shallow inverted triangle.
        p.move(to: CGPoint(x: 0.04 * w, y: 0.06 * h))
        p.addLine(to: CGPoint(x: 0.96 * w, y: 0.06 * h))
        p.addLine(to: CGPoint(x: 0.54 * w, y: 0.52 * h))
        p.addLine(to: CGPoint(x: 0.46 * w, y: 0.52 * h))
        p.closeSubpath()
        // Stem.
        p.addRect(CGRect(x: 0.44 * w, y: 0.52 * h, width: 0.12 * w, height: 0.36 * h))
        // Base.
        p.addRect(CGRect(x: 0.24 * w, y: 0.88 * h, width: 0.52 * w, height: 0.10 * h))
        return p
    }
}
