//
//  SimpleMapApp.swift
//  SimpleMap
//
//  Created by Yehor Myropoltsev on 20.12.2024.
//

import ComposableArchitecture
import SwiftUI

@main
struct SimpleMapApp: App {
    var body: some Scene {
        WindowGroup {
            LocationMapView(
                store: Store(initialState: LocationMap.State()) {
                    LocationMap()
                }
            )
        }
    }
}
