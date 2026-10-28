//
//  ProDetectorService.swift
//  CleanMac
//
//  Created by Erick Chavez on 27/10/26.
//

import Foundation
final class ProDetectorService {
    static let shared = ProDetectorService()
    private init() {}
    func detect() -> ProDetectionResult {
        (try? ProDetectionResult.detect()) ?? ProDetectionResult(detectedTools: [])
    }
}
