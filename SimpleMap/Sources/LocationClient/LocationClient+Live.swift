//
//  LocationClient+Live.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import CoreLocation
import Dependencies
import Foundation
import Combine

extension LocationClient: DependencyKey {
    public static var liveValue: LocationClient {
        let manager = CLLocationManager()
        let delegate = Delegate()
        manager.delegate = delegate
        
        return Self(
            requestAuthorization: { type in
                switch type {
                case .whenInUse:
                    manager.requestWhenInUseAuthorization()
                case .always:
                    manager.requestAlwaysAuthorization()
                }
            },
            authorizationStatus: {
                manager.authorizationStatus
            },
            start: {
                manager.startUpdatingLocation()
            },
            stop: {
                manager.stopUpdatingLocation()
            },
            getCurrentLocation: {
                switch manager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    if let location = manager.location {
                        return location
                    } else {
                        manager.requestLocation()
                    }
                    throw LocationError.failed
                default:
                    throw LocationError.unauthorized
                }
            },
            authorizationUpdates: {
                delegate.authorizationSubject.values
            },
            locationUpdates: {
                delegate.locationSubject.values
            },
            errorUpdates: {
                delegate.errorSubject.values
            }
        )
    }
}

private extension LocationClient {
    final class Delegate: NSObject, CLLocationManagerDelegate {
        let authorizationSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
        let locationSubject = PassthroughSubject<CLLocation, Never>()
        let errorSubject = PassthroughSubject<Error, Never>()
        
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            authorizationSubject.send(status)
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            locationSubject.send(location)
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            errorSubject.send(error)
        }
    }
}

public enum LocationError: Error {
    case serviceDisabled
    case unauthorized
    case failed
}

extension LocationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .serviceDisabled:
            "Location services are disabled. Please enable them in Settings."
        case .unauthorized:
            "Location access is not authorized. Please allow access in Settings."
        case .failed:
            "Failed to get location. Please try again."
        }
    }
}
