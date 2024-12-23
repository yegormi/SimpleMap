//
//  MKCoordinateRegion+Equatable.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import Foundation
import MapKit

extension MKCoordinateRegion: @retroactive Equatable {
    public static let defaultEpsilon: CLLocationDegrees = 0.000001

    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return abs(lhs.center.latitude - rhs.center.latitude) < defaultEpsilon &&
            abs(lhs.center.longitude - rhs.center.longitude) < defaultEpsilon &&
            abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < defaultEpsilon &&
            abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < defaultEpsilon
    }
}
