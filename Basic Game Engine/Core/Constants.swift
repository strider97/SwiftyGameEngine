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
    static let probeGrid = (10, 8, 8)
    static let probeCount = 640
    static let probeReso = 16
}
