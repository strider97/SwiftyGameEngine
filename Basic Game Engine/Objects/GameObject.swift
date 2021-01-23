//
//  GameObject.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

typealias Matrix4 = simd_float4x4

class GameObject {
    var position: Float3
    var modelMatrix: Matrix4
    var mesh: Mesh?
    
    init() {
        position = Float3(repeating: 0)
        modelMatrix = Matrix4(1)
    }
    init (_ position: Float3) {
        self.position = position
        modelMatrix = Matrix4(1)
    }
}

class Mesh {
    var vertices: [Float3]?
    var vertexBuffer: MTLBuffer?
}
