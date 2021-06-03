//
//  RendererManager.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class SceneRenderer {
    var view: MTKView
    var device: MTLDevice?

    init(_ device: MTLDevice?, view: MTKView) {
        self.device = device
        self.view = view
    }

    func draw() {}
}

extension SceneRenderer {}
