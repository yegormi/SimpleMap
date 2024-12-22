//
//  LocationError.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import CoreLocation
import Combine
import Dependencies
import Foundation

extension LocationClient: DependencyKey {
    public static var liveValue: LocationClient {
        let manager = CLLocationManager()
        let subject = PassthroughSubject<Action, Never>()
        
        let delegate = Delegate(subject: subject)
        manager.delegate = delegate
        
        return LocationClient(
            requestAuthorization: { type in
                switch type {
                case .whenInUse:
                    manager.requestWhenInUseAuthorization()
                case .always:
                    manager.requestAlwaysAuthorization()
                }
            },
            delegateUpdates: { subject.values }
        )
    }
}

private extension LocationClient {
    final class Delegate: NSObject, CLLocationManagerDelegate {
        let subject: PassthroughSubject<Action, Never>
        
        init(subject: PassthroughSubject<Action, Never>) {
            self.subject = subject
            super.init()
        }
        
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            subject.send(.didChangeAuthorization(manager.authorizationStatus))
        }
    }
}
