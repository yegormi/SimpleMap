import _MapKit_SwiftUI
import ComposableArchitecture
import CoreLocation
import Foundation
import MapKit
import OSLog
import UIKit

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

                switch status {
                case .notDetermined:
                    return .concatenate(
                        .send(.startListening),
                        .send(.requestAuthorization)
                    )

                case .denied, .restricted:
                    return .concatenate(
                        .send(.startListening),
                        .send(.authorizationStatusChanged(status))
                    )

                case .authorizedAlways, .authorizedWhenInUse:
                    return .send(.startListening)

                @unknown default:
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

                return .run { _ in
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

            case let .onLocationUpdate(result):
                switch result {
                case let .success(location):
                    state.currentLocation = location
                    return .none

                case let .failure(error):
                    logger.error("Location error occurred: \(error.localizedDescription)")
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
            center: CLLocationCoordinate2D(latitude: 48.4647, longitude: 35.0462),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
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
            authorization = LocationAuthorization.State()
            updates = LocationUpdates.State()
            camera = MapCamera.State()
        }
    }

    public enum Action: ViewAction {
        case authorization(LocationAuthorization.Action)
        case updates(LocationUpdates.Action)
        case camera(MapCamera.Action)
        case destination(PresentationAction<Destination.Action>)
        case view(View)
        case `internal`(Internal)

        public enum Internal {
            case changeDestination(Destination.State)
            case zoomToCurrentLocation(Result<CLLocation, Error>)
        }

        public enum View: BindableAction {
            case binding(BindingAction<State>)
            case onAppear
            case getCurrentLocationButtonTapped
        }
    }

    @Reducer(state: .equatable)
    public enum Destination {
        case alert(AlertState<AlertAction>)
        case plainAlert(AlertState<Never>)

        public enum AlertAction: Equatable {
            case openSettings
        }
    }

    @Dependency(\.openURL) var openURL
    @Dependency(\.locationClient) var location

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

        Reduce {
            state,
                action in
            switch action {
            case let .authorization(.authorizationStatusChanged(status)):
                logger.debug("Authorization status changed: \(status.rawValue)")

                switch status {
                case .denied,
                     .restricted:
                    return .send(.internal(.changeDestination(.alert(.serviceDisabled))))

                case .authorizedAlways,
                     .authorizedWhenInUse:
                    return .concatenate(
                        .send(.updates(.startListening)),
                        .send(.updates(.startTracking))
                    )

                default:
                    return .none
                }

            case let .updates(.onLocationUpdate(result)):
                switch result {
                case let .success(location):
                    logger.debug("Location updated: \(location)")
                    return .none

                case let .failure(error):
                    logger.error("Location error occurred: \(error.localizedDescription)")
                    return .send(.internal(.changeDestination(.plainAlert(.failed(error)))))
                }

            case .view(.binding):
                return .none

            case .view(.onAppear):
                logger.debug("View appeared")
                return .send(.authorization(.checkInitialStatus))

            case .view(.getCurrentLocationButtonTapped):
                logger.debug("Get current location tapped")

                let isAuthorized =
                    state.authorization.authorizationStatus == .authorizedWhenInUse ||
                    state.authorization.authorizationStatus == .authorizedAlways

                guard isAuthorized else { return .none }
                return .run { [state] send in
                    await send(.updates(.requestSingleLocation))
                    await send(.internal(.zoomToCurrentLocation(Result {
                        if let location = state.updates.currentLocation {
                            return location
                        } else {
                            return try await location.getCurrentLocation()
                        }
                    })))
                }

            case let .internal(.changeDestination(destination)):
                state.destination = destination
                return .none

            case let .internal(.zoomToCurrentLocation(result)):
                switch result {
                case let .success(location):
                    return .send(.camera(.updateRegion(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                    ))), animation: .spring)

                case let .failure(error):
                    return .send(.internal(.changeDestination(.plainAlert(.failed(error)))))
                }

            case .destination(.presented(.alert(.openSettings))):
                return .run { _ in
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(settingsUrl)
                }

            case .authorization,
                 .updates,
                 .camera,
                 .destination,
                 .internal:
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
}

extension AlertState where Action == LocationMap.Destination.AlertAction {
    static var serviceDisabled: Self {
        Self {
            TextState("Location Services Disabled")
        } actions: {
            ButtonState(action: .openSettings) {
                TextState("Open Settings")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        } message: {
            TextState("Please enable Location Services in Settings to use this feature.")
        }
    }
}
