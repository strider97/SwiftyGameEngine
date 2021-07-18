//
//  Constants.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

enum MathConstants: Float {
    case PI = 3.1415926535
}

struct Colors {
    static let clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
}

struct Constants {
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    static let smoothNormal: String = "newNormal"
    static let probeGrid = (12, 6, 8)//(24/2, 6/2, 12/2)
    static var probeCount: Int { Self.probeGrid.0 * Self.probeGrid.1 * Self.probeGrid.2 }
    static let probeReso = 24
    static let shadowProbeReso = 64;
    static let radianceProbeReso = 24;
    
    struct Labels {
        static let normalBias = "normalBias"
        static let depthBias = "depthBias"
        static let exposure = "exposure"
        static let ka = "ka"
        static let kd = "kd"
    }
}
