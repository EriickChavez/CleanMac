//
//  CleanMacApp.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI

@main
struct CleanMacApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] CleanMac iniciado")
        
        // Setup menu bar
        MenuBarService.shared.setup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
