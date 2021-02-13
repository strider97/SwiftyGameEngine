//
//  Renderer.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit
typealias Device = MTLDeviceObject

struct ShaderMaterial {
    var baseColor: Float3
}

class Material {
    var baseColor = Float3(repeating: 1)
    var roughness = 0
    var albedo: MTLTexture?
    private let library = Device.sharedDevice.library
    var fragmentShaderFunction: MTLFunction?
    var vertexShaderFunction: MTLFunction?
    init() {
        vertexShaderFunction = library?.makeFunction(name: "basicVertexShader")
        fragmentShaderFunction = library?.makeFunction(name: "basicFragmentShader")
    }
    init(_ fragmentShader: String, _ vertexShader: String) {
        fragmentShaderFunction = library?.makeFunction(name: fragmentShader)
        vertexShaderFunction = library?.makeFunction(name: vertexShader)
    }
    convenience init(_ material: MDLMaterial?) {
        self.init()
        if let material = material {
            baseColor = material.property(with: .baseColor)?.float3Value ?? Float3(repeating: 1)
        }
    }
}

