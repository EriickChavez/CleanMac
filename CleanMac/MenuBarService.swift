//
//  MenuBarService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import SwiftUI
import AppKit

final class MenuBarService: NSObject {
    static let shared = MenuBarService()
    private var statusItem: NSStatusItem?
    var totalSizeGB: Double = 0
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "trash.circle.fill", accessibilityDescription: "Clear")
            button.image?.isTemplate = true
        }
        updateMenu()
    }
    
    func updateTotalSize(files: [FileItem], caches: [AppCacheInfo]) {
        let filesGB = files.reduce(0) { $0 + $1.sizeMB } / 1024
        let cachesGB = caches.reduce(0) { $0 + $1.totalSizeMB } / 1024
        totalSizeGB = filesGB + cachesGB
        DispatchQueue.main.async { self.updateMenu() }
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        let sizeItem = NSMenuItem(title: String(format: "🧹 %.2f GB por limpiar", totalSizeGB), action: nil, keyEquivalent: "")
        sizeItem.isEnabled = false
        menu.addItem(sizeItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Abrir Clear", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Limpiar rápido", action: #selector(quickClean), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quickClean() {
        Task {
            if let files = try? ScannerService.shared.scanDownloads() {
                try? SmartTrashService.shared.deleteNow(files: files)
            }
        }
    }
}
