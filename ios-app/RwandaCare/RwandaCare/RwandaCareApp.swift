//
//  RwandaCareApp.swift
//  RwandaCare
//
//  Created by isaac nshuti on 27/02/2026.
//

import SwiftUI

@main
struct RwandaCareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    DataStore.shared.handleOpenURL(url)
                }
        }
    }
}
