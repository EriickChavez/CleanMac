//
//  MenuBarService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
import SwiftUI
import Combine
import AppKit

// MARK: - MenuBarService
/// Servicio para el icono en la menu bar (futuro)
@MainActor
final class MenuBarService: ObservableObject {
    
    static let shared = MenuBarService()
    
    // MARK: - Published
    
    @Published var totalGB: Double = 0
    
    // MARK: - Private
    
    private var statusItem: NSStatusItem?
    
    // MARK: - Init
    
    private init() {
        print("[MenuBarService] Inicializado")
    }
    
    // MARK: - Setup
    
    func setup() {
        print("[MenuBarService] Setup completado")
        // Por ahora no crea statusItem, solo prepara
        // En el futuro aquí irá el icono de la menu bar
    }
    
    // MARK: - Update
    
    func update(totalGB: Double) {
        self.totalGB = totalGB
        print("[MenuBarService] Total actualizado: \(totalGB)GB")
    }
}
