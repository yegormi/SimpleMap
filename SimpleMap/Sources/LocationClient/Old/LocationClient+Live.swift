////
////  LocationError.swift
////  SimpleMap
////
////  Created by Yehor Myropoltsev on 20.12.2024.
////
//
//import CoreLocation
//import Dependencies
//import Foundation
//
//public enum LocationError: Error {
//    case serviceDisabled
//    case unauthorized
//    case failed
//}
//
//extension LocationError: LocalizedError {
//    public var errorDescription: String? {
//        switch self {
//        case .serviceDisabled:
//            "Location services are disabled. Please enable them in Settings."
//        case .unauthorized:
//            "Location access is not authorized. Please allow access in Settings."
//        case .failed:
//            "Failed to get location. Please try again."
//        }
//    }
//}
//
//extension LocationClient: DependencyKey {
//    public static let liveValue: LocationClient = {
//        let manager = CLLocationManager()
//        
//        return LocationClient(
//            requestAuthorization: {
//                manager.requestWhenInUseAuthorization()
//            },
//            getCurrentLocation: {
//                guard CLLocationManager.locationServicesEnabled() else {
//                    throw LocationError.serviceDisabled
//                }
//                
//                switch manager.authorizationStatus {
//                case .authorizedWhenInUse, .authorizedAlways:
//                    if let location = manager.location {
//                        return location
//                    }
//                    throw LocationError.failed
//                default:
//                    throw LocationError.unauthorized
//                }
//            },
//            locationServicesEnabled: CLLocationManager.locationServicesEnabled,
//            authorizationStatus: { manager.authorizationStatus }
//        )
//    }()
//}
