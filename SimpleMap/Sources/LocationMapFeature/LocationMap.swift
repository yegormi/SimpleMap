import ComposableArchitecture
import _MapKit_SwiftUI
import CoreLocation
import Foundation
import MapKit
import OSLog

private let logger = Logger(subsystem: "LocationMapFeature", category: "LocationMap")

// MARK: - Location Authorization
@Reducer
public struct LocationAuthorization: Reducer, Sendable {
    @ObservableState
    public struct State: Equatable {
        var authorizationStatus: CLAuthorizationStatus
        
        public init(authorizationStatus: CLAuthorizationStatus = .notDetermined) {
            self.authorizationStatus = authorizationStatus
        }
    }
    
    public enum Action {
        case checkInitialStatus
        case requestAuthorization
        case startListening
        case authorizationStatusChanged(CLAuthorizationStatus)
    }
    
    @Dependency(\.locationClient) var location
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkInitialStatus:
                let status = location.authorizationStatus()
                state.authorizationStatus = status
                
                if status == .notDetermined {
                    return .concatenate(
                        .send(.startListening),
                        .send(.requestAuthorization)
                    )
                } else {
                    return .send(.startListening)
                }
                
            case .requestAuthorization:
                return .run { _ in
                    await location.requestAuthorization(type: .whenInUse)
                }
                
            case .startListening:
                return .run { send in
                    for await status in location.authorizationUpdates() {
                        await send(.authorizationStatusChanged(status))
                    }
                }
                
            case let .authorizationStatusChanged(status):
                state.authorizationStatus = status
                return .none
            }
        }
    }
}

// MARK: - Location Updates
@Reducer
public struct LocationUpdates: Reducer, Sendable {
    @ObservableState
    public struct State: Equatable {
        var currentLocation: CLLocation?
        var isTracking: Bool
        
        public init(currentLocation: CLLocation? = nil, isTracking: Bool = false) {
            self.currentLocation = currentLocation
            self.isTracking = isTracking
        }
    }
    
    public enum Action {
        case startTracking
        case stopTracking
        case requestSingleLocation
        case startListening
        case onLocationUpdate(Result<CLLocation, Error>)
    }
    
    @Dependency(\.locationClient) var location
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startTracking:
                guard !state.isTracking else { return .none }
                state.isTracking = true
                
                return .run { send in
                    await location.start()
                }
                
            case .stopTracking:
                guard state.isTracking else { return .none }
                state.isTracking = false
                return .run { _ in
                    await location.stop()
                }
                
            case .startListening:
                return .merge(
                    .run { send in
                        for await location in location.locationUpdates() {
                            await send(.onLocationUpdate(.success(location)))
                        }
                    },
                    .run { send in
                        for await error in location.errorUpdates() {
                            await send(.onLocationUpdate(.failure(error)))
                        }
                    }
                )
                
            case .requestSingleLocation:
                return .run { send in
                    await send(.onLocationUpdate(Result {
                        try await location.getCurrentLocation()
                    }))
                }

            case .onLocationUpdate(let result):
                switch result {
                case .success(let location):
                    state.currentLocation = location
                    return .none
                    
                case .failure(let error):
                    return .none
                }
            }
        }
    }
}

// MARK: - Map Camera
@Reducer
public struct MapCamera: Reducer, Sendable {
    @ObservableState
    public struct State: Equatable {
        var cameraPosition: MapCameraPosition
        
        public init(cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))) {
            self.cameraPosition = cameraPosition
        }
    }
    
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case updateRegion(MKCoordinateRegion)
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case let .updateRegion(region):
                state.cameraPosition = .region(region)
                return .none
            }
        }
    }
}

// MARK: - Combined Location Map
@Reducer
public struct LocationMap: Reducer, Sendable {
    @ObservableState
    public struct State: Equatable {
        @Presents var destination: Destination.State?
        var authorization: LocationAuthorization.State
        var updates: LocationUpdates.State
        var camera: MapCamera.State
        
        public init() {
            self.authorization = LocationAuthorization.State()
            self.updates = LocationUpdates.State()
            self.camera = MapCamera.State()
        }
    }
    
    public enum Action: ViewAction {
        case authorization(LocationAuthorization.Action)
        case updates(LocationUpdates.Action)
        case camera(MapCamera.Action)
        case destination(PresentationAction<Destination.Action>)
        case view(View)
        
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
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.authorization, action: \.authorization) {
            LocationAuthorization()
        }
        Scope(state: \.updates, action: \.updates) {
            LocationUpdates()
        }
        Scope(state: \.camera, action: \.camera) {
            MapCamera()
        }
        
        BindingReducer(action: \.view)
        
        Reduce { state, action in
            switch action {
            case .authorization(.authorizationStatusChanged(let status)):
                logger.debug("Authorization status changed: \(status.rawValue)")
                
                switch status {
                case .denied, .restricted:
                    state.destination = .alert(.serviceDisabled)
                    return .none
                    
                case .notDetermined:
                    return .none
                    
                case .authorizedAlways, .authorizedWhenInUse:
                    return .concatenate(
                        .send(.updates(.startListening)),
                        .send(.updates(.startTracking))
                    )
                    
                @unknown default:
                    return .none
                }
                
            case let .updates(.onLocationUpdate(result)):
                switch result {
                case .success(let location):
                    logger.debug("Location updated: \(location)")
                    return .send(.camera(.updateRegion(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))))
                case .failure(let error):
                    logger.error("Location error occurred: \(error.localizedDescription)")
                    state.destination = .alert(.failed(error))
                    return .none
                }
                    
                
            case .view(.binding):
                return .none
                
            case .view(.onAppear):
                logger.debug("View appeared")
                return .send(.authorization(.checkInitialStatus))
                
            case .view(.getCurrentLocationButtonTapped):
                logger.debug("Get current location tapped")
                let isAuthorized = state.authorization.authorizationStatus == .authorizedWhenInUse
                    || state.authorization.authorizationStatus == .authorizedAlways
                guard isAuthorized else { return .none }
                return .send(.updates(.requestSingleLocation))
                
            case .authorization, .updates, .camera, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

// MARK: - Alert States
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
