//
//  PointLight.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 20/07/21.
//

import MetalKit

class PointLight {
    var position: Float3
    var intensity: Float
    var color: Float3
    var depthMap: MTLTexture!
    
    init(position: Float3 = Float3(0), intensity: Float = 10, color: Float3 = Float3(1)) {
        self.position = position
        self.intensity = intensity
        self.color = color
        depthMap = Descriptor.build2DTextureForWrite(pixelFormat: .rgba16Float, size: CGSize())
    }
}
