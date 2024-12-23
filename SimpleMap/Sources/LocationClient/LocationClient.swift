//
//  LocationClient.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import CoreLocation
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct LocationClient: Sendable {
    public var requestAuthorization: @Sendable (_ type: AuthorizationType) async -> Void
    public var authorizationStatus: @Sendable () -> CLAuthorizationStatus = { .notDetermined }
    public var start: @Sendable () async -> Void
    public var stop: @Sendable () async -> Void
    public var getCurrentLocation: @Sendable () async throws -> CLLocation
    public var authorizationUpdates: @Sendable () -> any AsyncSequence<CLAuthorizationStatus, Never> = { AsyncStream.never }
    public var locationUpdates: @Sendable () -> any AsyncSequence<CLLocation, Never> = { AsyncStream.never }
    public var errorUpdates: @Sendable () -> any AsyncSequence<Error, Never> = { AsyncStream.never }
}

public extension LocationClient {
    static let mock = LocationClient(
        requestAuthorization: { _ in unimplemented("\(Self.self).requestAuthorization") },
        authorizationStatus: { unimplemented("\(Self.self).authorizationStatus", placeholder: .notDetermined) },
        start: { unimplemented("\(Self.self).start") },
        stop: { unimplemented("\(Self.self).stop") },
        getCurrentLocation: { unimplemented("\(Self.self).getCurrentLocation", placeholder: CLLocation()) },
        authorizationUpdates: { unimplemented("\(Self.self).authorizationUpdates", placeholder: AsyncStream.never) },
        locationUpdates: { unimplemented("\(Self.self).locationUpdates", placeholder: AsyncStream.never) },
        errorUpdates: { unimplemented("\(Self.self).errorUpdates", placeholder: AsyncStream.never) }
    )
}

public extension LocationClient {
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
