import ComposableArchitecture
import CoreLocation
import Foundation
import MapKit
import OSLog
import _MapKit_SwiftUI

private let logger = Logger(subsystem: "LocationMapFeature", category: "LocationMap")

@Reducer
public struct LocationMap: Reducer, Sendable {
    @ObservableState
    public struct State: Equatable {
        @Presents var destination: Destination.State?
        var cameraPosition: MapCameraPosition
        var isLoading = false
        
        public init() {
            self.cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
    
    public enum Action: ViewAction {
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case `internal`(Internal)
        case view(View)
        
        public enum Delegate {}
        
        public enum Internal {
            case authorizationStatusUpdated(CLAuthorizationStatus)
        }
        
        public enum View: BindableAction {
            case binding(BindingAction<State>)
            case onAppear
            case getCurrentLocationButtonTapped
            case regionChanged(MKCoordinateRegion)
        }
    }
    
    @Reducer(state: .equatable)
    public enum Destination {
        case alert(AlertState<Never>)
    }
    
    @Dependency(\.locationClient) var location
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
        BindingReducer(action: \.view)
        
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
                
            case .destination:
                return .none
                
            case let .internal(.authorizationStatusUpdated(status)):
                logger.debug("Authorization status updated: \(status.customDumpDescription)")
                return .none
                
            case .view(.binding):
                return .none
                
            case .view(.onAppear):
                return .run { send in
//                    await send(.internal(.checkLocationServices))
//                    await location.requestAuthorization()
                    
//                    if location.authorizationStatus() == .authorizedWhenInUse {
//                        await send(.view(.startContinuousUpdates))
//                    }
                }
                
            case .view(.getCurrentLocationButtonTapped):
                guard !state.isLoading else { return .none }
                state.isLoading = true
                
                return .run { send in
//                    await send(.internal(.locationResult(Result {
//                        try await location.getCurrentLocation()
//                    })))
                }

            case let .view(.regionChanged(region)):
                state.cameraPosition = .region(region)
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension AlertState where Action == Never {
    static func failed(_ error: any Error) -> Self {
        Self {
            TextState("Failed to perform action")
        } actions: {
            ButtonState(role: .cancel) {
                TextState("OK")
            }
        } message: {
            TextState(error.localizedDescription)
        }
    }
    
    static var serviceDisabled: Self {
        Self {
            TextState("Location Services Disabled")
        } actions: {
            ButtonState(role: .cancel) {
                TextState("OK")
            }
        } message: {
            TextState("Please enable Location Services in Settings to use this feature.")
        }
    }
}
