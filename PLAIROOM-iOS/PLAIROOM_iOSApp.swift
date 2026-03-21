//
//  PLAIROOM_iOSApp.swift
//  PLAIROOM-iOS
//
//  Created by wada on 2026/03/14.
//

import ComposableArchitecture
import SwiftUI

@main
struct PLAIROOM_iOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }
}
