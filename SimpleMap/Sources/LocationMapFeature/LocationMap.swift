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
            case regionChanged(MKCoordinateRegion)
            case authorizationStatusChanged(CLAuthorizationStatus)
            case startLocationUpdates
        }
        
        public enum View: BindableAction {
            case binding(BindingAction<State>)
            case onAppear
            case getCurrentLocationButtonTapped
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
                
            case .internal(.regionChanged(let region)):
                state.cameraPosition = .region(region)
                return .none
                
            case .internal(.authorizationStatusChanged(let status)):
                switch status {
                case .denied, .restricted:
                    state.destination = .alert(.serviceDisabled)
                case .notDetermined:
                    break
                case .authorizedAlways, .authorizedWhenInUse:
                    break
                @unknown default:
                    break
                }
                return .none
                
            case .internal(.startLocationUpdates):
                return .run { send in
                    await location.start()
                    
                    for await event in location.events() {
                        switch event {
                        case let .didUpdateLocation(location):
                            logger.debug("Did update location: \(location)")
                            await send(.internal(.regionChanged(MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))))
                        case let .didChangeAuthorization(status):
                            logger.debug("Authorization status changed: \(status.rawValue)")
                            await send(.internal(.authorizationStatusChanged(status)))
                        case let .didFailWithError(error):
                            logger.error("Failed with error: \(error)")
                        }
                    }
                }
                
            case .view(.binding):
                return .none
                
            case .view(.onAppear):
                let authorizationStatus = location.authorizationStatus()
                
                switch authorizationStatus {
                case .notDetermined:
                    return .run { send in
                        await location.requestAuthorization(type: .always)
                        await send(.internal(.startLocationUpdates))
                    }
                    
                case .authorizedWhenInUse, .authorizedAlways:
                    return .run { send in
                        await send(.internal(.startLocationUpdates))
                    }
                    
                case .restricted, .denied:
                    state.destination = .alert(.serviceDisabled)
                    return .none
                    
                @unknown default:
                    return .none
                }
                
            case .view(.getCurrentLocationButtonTapped):
                let status = location.authorizationStatus()
                
                let isAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
                guard isAuthorized else { return .none }
                
                return .run { send in
                    await location.requestLocation()
                }
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
