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
    private let w = 2048
    private let minMipmapWidth = 64
    var vertices: [Vertex] = [
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(1.0, 0.0, 0.0, 1))
    ]
    var mipMaps: [MTLTexture] = []
    var renderPassDescriptors: [MTLRenderPassDescriptor] = []
    var mipMapCount = 0
    
    init() {
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride*vertices.count, options: [])!
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: w, height: w/2), mipmapped: true);
        pipelineState = Descriptor.createIrradianceMapPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
        generateTextureForMipmaps(w)
    }
    
    func generateTextureForMipmaps(_ w: Int) {
        var width = self.w
        while width >= minMipmapWidth {
            let texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: width, height: width/2));
            let renderPassDescriptorMipmap = MTLRenderPassDescriptor()
            renderPassDescriptorMipmap.setupColorAttachment(texture)
            mipMaps.append(texture)
            renderPassDescriptors.append(renderPassDescriptorMipmap)
            mipMapCount += 1
            width /= 2
        }
    }
}

class DFGLut {
    var texture: MTLTexture!
    var renderPassDescriptor = MTLRenderPassDescriptor()
    var pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    var vertices: [Vertex] = [
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(1.0, 0.0, 0.0, 1))
    ]
    
    init() {
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride*vertices.count, options: [])!
        
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: 1024, height: 1024));
        pipelineState = Descriptor.createDFGLUTPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
    }
}
