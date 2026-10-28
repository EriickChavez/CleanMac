//
//  DashboardService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - DashboardService
/// Servicio que lleva el control de cuánto has limpiado
/// ObservableObject para que la UI se actualice sola
@MainActor
final class DashboardService: ObservableObject {
    
    static let shared = DashboardService()
    
    // MARK: - Published Properties
    // Estas propiedades hacen que la UI se redibuje cuando cambian
    
    @Published var totalFreedMB: Double = 0
    @Published var cleanCount: Int = 0
    @Published var healthScore: Int = 100
    @Published var history: [CleanEvent] = []
    
    // MARK: - CleanEvent
    
    struct CleanEvent: Identifiable, Codable {
        var id: UUID = UUID()
        var date: Date = Date()
        var freedMB: Double
        var type: String
        
        var dateText: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        var sizeText: String {
            FileItem.formatMB(freedMB)
        }
    }
    
    // MARK: - Init
    
    private init() {
        // Cargar datos guardados
        totalFreedMB = UserDefaults.standard.double(forKey: "totalFreedMB")
        cleanCount = UserDefaults.standard.integer(forKey: "cleanCount")
        
        if let data = UserDefaults.standard.data(forKey: "cleanHistory") {
            if let decoded = try? JSONDecoder().decode([CleanEvent].self, from: data) {
                history = decoded
            }
        }
        
        print("[DashboardService] Inicializado - Total liberado: \(totalFreedMB)MB, Limpiezas: \(cleanCount)")
    }
    
    // MARK: - Track Clean
    
    func trackClean(freedMB: Double, type: String) {
        
        totalFreedMB += freedMB
        cleanCount += 1
        
        let event = CleanEvent(freedMB: freedMB, type: type)
        history.insert(event, at: 0)
        
        // Limitar historial a 50 eventos
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        // Guardar en UserDefaults
        UserDefaults.standard.set(totalFreedMB, forKey: "totalFreedMB")
        UserDefaults.standard.set(cleanCount, forKey: "cleanCount")
        
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "cleanHistory")
        }
        
        print("[DashboardService] Limpieza registrada: \(freedMB)MB tipo \(type)")
    }
    
    // MARK: - Health
    
    func updateHealth(totalGB: Double) {
        // Menos de 5GB = 100%, cada GB extra baja 2%
        let score = max(0, 100 - Int(totalGB * 2))
        healthScore = score
        
        print("[DashboardService] Health actualizado: \(score)% para \(totalGB)GB")
    }
    
    // MARK: - Reset
    
    func resetStats() {
        totalFreedMB = 0
        cleanCount = 0
        history = []
        
        UserDefaults.standard.removeObject(forKey: "totalFreedMB")
        UserDefaults.standard.removeObject(forKey: "cleanCount")
        UserDefaults.standard.removeObject(forKey: "cleanHistory")
        
        print("[DashboardService] Stats reseteados")
    }
}
