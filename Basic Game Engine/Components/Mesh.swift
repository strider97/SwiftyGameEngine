//
//  Mesh.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

class Mesh: Component {
    var vertices: [Vertex] = []
    var vertexBuffer: MTLBuffer?
    var vertexDescriptor: MTLVertexDescriptor!
    
    init(vertices: [Vertex]) {
        super.init()
        self.vertices = vertices
        let device = MTLDeviceObject.sharedDevice.device
        vertexBuffer = device?.makeBuffer(bytes: self.vertices, length: MemoryLayout<Vertex>.stride, options: [])
        loadDescriptor()
    }
    
    func loadDescriptor() {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float3>.size
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        self.vertexDescriptor = vertexDescriptor
    }
}


