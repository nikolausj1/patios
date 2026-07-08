import SwiftUI
import MapKit

/// A revealable map showing the user and the selected patio. Opened from the
/// map button on the compass screen (the "show me on a map" affordance).
struct PatioMapView: View {
    let patio: Patio
    let userLocation: CLLocationCoordinate2D?

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition

    init(patio: Patio, userLocation: CLLocationCoordinate2D?) {
        self.patio = patio
        self.userLocation = userLocation
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: patio.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        ))
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
                Marker(patio.name, systemImage: "fork.knife", coordinate: patio.coordinate)
                    .tint(Theme.accent)
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .safeAreaInset(edge: .bottom) { infoCard }
            .navigationTitle(patio.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        MKMapItem(placemark: MKPlacemark(coordinate: patio.coordinate))
                            .openInMaps(launchOptions: [
                                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                            ])
                    } label: {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var infoCard: some View {
        Group {
            if let address = patio.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}
