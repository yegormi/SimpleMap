////
////  LocationClient 2.swift
////  SimpleMap
////
////  Created by Yehor Myropoltsev on 20.12.2024.
////
//
//
//import Dependencies
//import DependenciesMacros
//@preconcurrency import CoreLocation
//import Foundation
//import OSLog
//
//private let logger = Logger(subsystem: "com.SimpleMap", category: "LocationClient")
//
//@DependencyClient
//public struct LocationClient: Sendable {
//    /// Requests location authorization from the user
//    public var requestAuthorization: @Sendable () async -> Void
//    
//    /// Gets the current location once
//    public var getCurrentLocation: @Sendable () async throws -> CLLocation
//    
//    /// Starts continuous location updates
//    public var startUpdatingLocation: @Sendable () async -> AsyncStream<CLLocation> = { .never }
//    
//    /// Stops continuous location updates
//    public var stopUpdatingLocation: @Sendable () -> Void
//    
//    /// Checks if location services are enabled
//    public var locationServicesEnabled: @Sendable () -> Bool = { false }
//    
//    /// Gets the current authorization status
//    public var authorizationStatus: @Sendable () -> CLAuthorizationStatus = { .notDetermined }
//    
//    /// Gets the current location accuracy authorization
//    public var accuracyAuthorization: @Sendable () -> CLAccuracyAuthorization = { .reducedAccuracy }
//    
//    /// Requests temporary full accuracy authorization
//    public var requestTemporaryFullAccuracyAuthorization: @Sendable (String) async throws -> Bool
//}
//
//// MARK: - Live Implementation
//extension LocationClient: DependencyKey {
//    public static let liveValue: LocationClient = {
//        let manager = CLLocationManager()
//        manager.desiredAccuracy = kCLLocationAccuracyBest
//        manager.distanceFilter = 10 // meters
//        
//        let delegate = LocationManagerDelegate()
//        manager.delegate = delegate
//        
//        return LocationClient(
//            requestAuthorization: { @MainActor in
//                manager.requestWhenInUseAuthorization()
//            },
//            getCurrentLocation: {
//                try await withCheckedThrowingContinuation { continuation in
//                    guard CLLocationManager.locationServicesEnabled() else {
//                        continuation.resume(throwing: LocationError.serviceDisabled)
//                        return
//                    }
//                    
//                    switch manager.authorizationStatus {
//                    case .authorizedWhenInUse, .authorizedAlways:
//                        if let location = manager.location {
//                            continuation.resume(returning: location)
//                        } else {
//                            delegate.oneTimeLocationRequest = continuation
//                            manager.requestLocation()
//                        }
//                    case .notDetermined:
//                        continuation.resume(throwing: LocationError.notDetermined)
//                    case .denied, .restricted:
//                        continuation.resume(throwing: LocationError.unauthorized)
//                    @unknown default:
//                        continuation.resume(throwing: LocationError.unknown)
//                    }
//                }
//            },
//            startUpdatingLocation: {
//                await MainActor.run {
//                    manager.startUpdatingLocation()
//                }
//                return delegate.locationStream
//            },
//            stopUpdatingLocation: {
//                manager.stopUpdatingLocation()
//            },
//            locationServicesEnabled: CLLocationManager.locationServicesEnabled,
//            authorizationStatus: { manager.authorizationStatus },
//            accuracyAuthorization: { manager.accuracyAuthorization },
//            requestTemporaryFullAccuracyAuthorization: { purposeKey in
//                try await withCheckedThrowingContinuation { continuation in
//                    guard #available(iOS 14.0, *) else {
//                        continuation.resume(returning: true)
//                        return
//                    }
//                    
//                    manager.requestTemporaryFullAccuracyAuthorization(
//                        withPurposeKey: purposeKey
//                    ) { error in
//                        if let error = error {
//                            continuation.resume(throwing: error)
//                        } else {
//                            continuation.resume(
//                                returning: manager.accuracyAuthorization == .fullAccuracy
//                            )
//                        }
//                    }
//                }
//            }
//        )
//    }()
//}
//
////
////  LocationClient2.swift
////  SimpleMap
////
////  Created by Yehor Myropoltsev on 20.12.2024.
////
//
//import Foundation
//
//public extension LocationClient {
//    static let mock = Self(
//        requestAuthorization: {},
//        getCurrentLocation: {
//            CLLocation(latitude: 37.3348, longitude: -122.0090) // Apple Park
//        },
//        startUpdatingLocation: {
//            AsyncStream { continuation in
//                continuation.yield(CLLocation(latitude: 37.3348, longitude: -122.0090))
//                continuation.finish()
//            }
//        },
//        stopUpdatingLocation: {},
//        locationServicesEnabled: { true },
//        authorizationStatus: { .authorizedWhenInUse },
//        accuracyAuthorization: { .fullAccuracy },
//        requestTemporaryFullAccuracyAuthorization: { _ in true }
//    )
//}
//
//extension LocationClient: TestDependencyKey {
//    public static let previewValue = Self.mock
//    public static let testValue = Self()
//}
//
//// MARK: - Dependency Registration
//public extension DependencyValues {
//    var locationClient: LocationClient {
//        get { self[LocationClient.self] }
//        set { self[LocationClient.self] = newValue }
//    }
//}
//
//public enum LocationError: LocalizedError {
//    case serviceDisabled
//    case unauthorized
//    case notDetermined
//    case failed
//    case unknown
//    case accuracyRestricted
//    
//    public var errorDescription: String? {
//        switch self {
//        case .serviceDisabled:
//            "Location services are disabled. Please enable them in Settings."
//        case .unauthorized:
//            "Location access is not authorized. Please allow access in Settings."
//        case .notDetermined:
//            "Location authorization status not yet determined."
//        case .failed:
//            "Failed to get location. Please try again."
//        case .unknown:
//            "An unknown error occurred while accessing location."
//        case .accuracyRestricted:
//            "Full location accuracy is not available. Please check your settings."
//        }
//    }
//    
//    public var recoverySuggestion: String? {
//        switch self {
//        case .serviceDisabled:
//            "Go to Settings > Privacy > Location Services and turn on Location Services."
//        case .unauthorized:
//            "Go to Settings > Privacy > Location Services > Your App and select 'While Using the App'."
//        case .notDetermined:
//            "Please grant location access when prompted."
//        case .failed, .unknown:
//            "Check your internet connection and try again."
//        case .accuracyRestricted:
//            "Go to Settings > Privacy > Location Services > Your App and select 'Precise Location'."
//        }
//    }
//}
//
//final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
//    private let locationSubject = AsyncStream<CLLocation>.makeStream()
//    private let authorizationSubject = AsyncStream<CLAuthorizationStatus>.makeStream()
//    
//    var oneTimeLocationRequest: CheckedContinuation<CLLocation, Error>?
//    var locationStream: AsyncStream<CLLocation> { locationSubject.stream }
//    var authorizationStream: AsyncStream<CLAuthorizationStatus> { authorizationSubject.stream }
//    
//    func locationManager(
//        _ manager: CLLocationManager,
//        didUpdateLocations locations: [CLLocation]
//    ) {
//        guard let location = locations.last else { return }
//        
//        if let continuation = oneTimeLocationRequest {
//            oneTimeLocationRequest = nil
//            continuation.resume(returning: location)
//        }
//        
//        locationSubject.continuation.yield(location)
//    }
//    
//    func locationManager(
//        _ manager: CLLocationManager,
//        didFailWithError error: Error
//    ) {
//        if let continuation = oneTimeLocationRequest {
//            oneTimeLocationRequest = nil
//            continuation.resume(throwing: error)
//        }
//        
//        logger.error("Location manager failed with error: \(error.localizedDescription)")
//    }
//    
//    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
//        authorizationSubject.continuation.yield(manager.authorizationStatus)
//    }
//    
//    deinit {
//        locationSubject.continuation.finish()
//        authorizationSubject.continuation.finish()
//    }
//}
