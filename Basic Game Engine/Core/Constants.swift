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
    static let clearColor = Float4(0.1, 0.1, 0.1, 1)
}

struct Constants {
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    
}
