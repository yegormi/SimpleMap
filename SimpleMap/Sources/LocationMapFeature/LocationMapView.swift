//
//  LocationMapView.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import ComposableArchitecture
import MapKit
import SwiftUI

@ViewAction(for: LocationMap.self)
public struct LocationMapView: View {
    @Bindable public var store: StoreOf<LocationMap>
    
    public init(store: StoreOf<LocationMap>) {
        self.store = store
    }
    
    public var body: some View {
        Map(position: self.$store.camera.cameraPosition) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                send(.getCurrentLocationButtonTapped, animation: .smooth)
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(16)
        }
        .onAppear {
            send(.onAppear)
        }
        .alert(
            store: self.store.scope(state: \.$destination.alert, action: \.destination.alert)
        )
    }
}

#Preview {
    LocationMapView(
        store: Store(initialState: LocationMap.State()) {
            LocationMap()
        }
    )
}
