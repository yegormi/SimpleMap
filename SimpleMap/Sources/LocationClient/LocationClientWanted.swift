//
//  LocationClient.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import Dependencies
import DependenciesMacros
import CoreLocation
import Foundation

@DependencyClient
public struct LocationClient: Sendable {
    public var requestAuthorization: @Sendable (_ type: AuthorizationType) async -> Void
    public var authorizationStatus: @Sendable () -> CLAuthorizationStatus = { .notDetermined }
    public var start: @Sendable () async -> Void
    public var stop: @Sendable () async -> Void
    public var requestLocation: @Sendable () async -> Void
    public var events: @Sendable () -> any AsyncSequence<Event, Never> = { AsyncStream.never }
}

public extension LocationClient {
    static let mock = LocationClient(
        requestAuthorization: { _ in unimplemented("\(Self.self).requestAuthorization") },
        authorizationStatus: { unimplemented("\(Self.self).authorizationStatus", placeholder: .notDetermined) },
        start: { unimplemented("\(Self.self).start") },
        stop: { unimplemented("\(Self.self).stop") },
        requestLocation: { unimplemented("\(Self.self).requestLocation") },
        events: { unimplemented("\(Self.self).delegateUpdates", placeholder: AsyncStream.never) }
    )
}

public extension LocationClient {
    enum Event {
        case didChangeAuthorization(CLAuthorizationStatus)
        case didUpdateLocation(CLLocation)
        case didFailWithError(Error)
    }
    
    enum AuthorizationType {
        case whenInUse
        case always
    }
}

extension LocationClient: TestDependencyKey {
    public static let previewValue = LocationClient.mock
    public static let testValue = LocationClient()
}

public extension DependencyValues {
    var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}
