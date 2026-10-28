//
//  SmartTrashService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
final class SmartTrashService {
    static let shared = SmartTrashService()
    private init() {}
    func moveToSmartTrash(path: String) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
    }
}
