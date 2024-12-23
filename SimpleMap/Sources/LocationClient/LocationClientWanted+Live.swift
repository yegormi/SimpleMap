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
            requestLocation: {
                manager.requestLocation()
            },
            events: {
                delegate.subject.values
            }
        )
    }
}

private extension LocationClient {
    final class Delegate: NSObject, CLLocationManagerDelegate {
        let subject = PassthroughSubject<Event, Never>()
        
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            subject.send(.didChangeAuthorization(status))
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            subject.send(.didUpdateLocation(location))
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            subject.send(.didFailWithError(error))
        }
    }
}
