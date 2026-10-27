//
//  SmartTrashService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation

final class SmartTrashService: Sendable {
    static let shared = SmartTrashService()
    func cleanupExpired() {}
    func moveToSmartTrash(files: [FileItem], days: Int) throws {
        for f in files { try? FileManager.default.removeItem(atPath: f.path) }
    }
    func deleteNow(files: [FileItem]) throws {
        for f in files { try? FileManager.default.removeItem(atPath: f.path) }
    }
}
