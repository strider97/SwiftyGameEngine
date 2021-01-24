//
//  Models.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class BasicModelsVertices {
    static let triangle: [Vertex] = [
        Vertex(position: Float3(-0.5, -0.5, 0), color: Float4(0.17, 0.32, 0.54, 1)),
        Vertex(position: Float3(0, 0.5, 0), color: Float4(0.3, 0.5, 0.7, 1)),
        Vertex(position: Float3(0.5, -0.5, 0), color: Float4(0.2, 0.6, 0.4, 1))
    ]
}
