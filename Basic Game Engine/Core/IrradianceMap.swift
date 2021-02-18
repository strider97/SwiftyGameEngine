//
//  IrradianceMap.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 18/02/21.
//

import MetalKit

class IrradianceMap {
    var texture: MTLTexture!
    var renderPassDescriptor = MTLRenderPassDescriptor()
    var pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    var vertices: [Vertex] = [
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.17, 0.32, 0.54, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.3, 0.5, 0.7, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(0.2, 0.6, 0.4, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(0.7, 0.2, 1, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.3, 0.3, 0.7, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(0.42, 0.1, 0.4, 1))
    ]
    
    init() {
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride*vertices.count, options: [])!
        
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: 512, height: 256));
        pipelineState = Descriptor.createIrradianceMapPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
    }
}
