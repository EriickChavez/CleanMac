//
//  CleanMacApp.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI

@main
struct ClearApp: App {
    init() {
        MenuBarService.shared.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
