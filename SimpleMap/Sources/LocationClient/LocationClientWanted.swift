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
    public var delegateUpdates: @Sendable () -> any AsyncSequence<Action, Never> = { AsyncStream.never }
}

public extension LocationClient {
    static let mock = LocationClient(
        requestAuthorization: { _ in },
        delegateUpdates: { unimplemented("\(Self.self).delegateUpdates", placeholder: AsyncStream.never) }
    )
}

public extension LocationClient {
    enum Action {
        case didChangeAuthorization(CLAuthorizationStatus)
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
