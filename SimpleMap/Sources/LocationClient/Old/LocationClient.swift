////
////  LocationClient.swift
////  SimpleMap
////
////  Created by Yehor Myropoltsev on 20.12.2024.
////
//
//import Dependencies
//import DependenciesMacros
//import CoreLocation
//import Foundation
//
//@DependencyClient
//public struct LocationClient: Sendable {
//    public var requestAuthorization: @Sendable () async -> Void
//    public var getCurrentLocation: @Sendable () async throws -> CLLocation
//    public var locationServicesEnabled: @Sendable () -> Bool = { false }
//    public var authorizationStatus: @Sendable () -> CLAuthorizationStatus = { .notDetermined }
//}
//
//public extension LocationClient {
//    static let mock = LocationClient(
//        requestAuthorization: {},
//        getCurrentLocation: { unimplemented("\(Self.self).getCurrentLocation", placeholder: CLLocation()) },
//        locationServicesEnabled: { unimplemented("\(Self.self).locationServicesEnabled", placeholder: true) },
//        authorizationStatus: { unimplemented("\(Self.self).authorizationStatus", placeholder: .authorizedWhenInUse) }
//    )
//}
//
//extension LocationClient: TestDependencyKey {
//    public static let previewValue = LocationClient.mock
//    public static let testValue = LocationClient()
//}
//
//public extension DependencyValues {
//    var locationClient: LocationClient {
//        get { self[LocationClient.self] }
//        set { self[LocationClient.self] = newValue }
//    }
//}
