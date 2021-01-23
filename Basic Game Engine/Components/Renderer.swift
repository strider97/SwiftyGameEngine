//
//  Renderer.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit
typealias Device = MTLDeviceObject

class Renderer: Component {
    var material: Material = Material()
}

class Material {
    let library = Device.sharedDevice.library
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
}
