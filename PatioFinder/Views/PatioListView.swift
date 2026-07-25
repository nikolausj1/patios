import SwiftUI

/// A sheet listing nearby patios sorted by distance. Tap one to point the arrow at it.
struct PatioListView: View {
    @ObservedObject var viewModel: PatioViewModel
    @ObservedObject var location: LocationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.patios.enumerated()), id: \.element.id) { index, patio in
                    Button {
                        viewModel.select(patio)
                        dismiss()
                    } label: {
                        row(for: patio, index: index)
                    }
                    .listRowBackground(index == viewModel.selectedIndex
                                       ? Theme.accent.opacity(0.12) : nil)
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top) { alcoholFilterBar }
            .navigationTitle("Nearby Patios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Segmented control for the global alcohol filter: "Adult Drinks" (only
    /// places that serve alcohol) vs. "All Patios".
    private var alcoholFilterBar: some View {
        Picker("Patio filter", selection: Binding(
            get: { viewModel.alcoholOnly },
            set: { newValue in withAnimation { viewModel.alcoholOnly = newValue } }
        )) {
            Text("Adult Drinks").tag(true)
            Text("All Patios").tag(false)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func row(for patio: Patio, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(index == viewModel.selectedIndex
                          ? Theme.accent : Theme.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: index == 0 ? "location.fill" : "fork.knife")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(index == viewModel.selectedIndex ? .white : Theme.accentDeep)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(patio.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let address = patio.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                if let openNow = patio.openNow {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(openNow ? .green : .red)
                            .frame(width: 6, height: 6)
                        Text(openNow ? "Open" : "Closed")
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer()

            if let text = distanceText(for: patio) {
                Text(text)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func distanceText(for patio: Patio) -> String? {
        guard let user = location.location else { return nil }
        return DistanceFormatter.string(fromMeters: user.distance(from: patio.location))
    }
}
