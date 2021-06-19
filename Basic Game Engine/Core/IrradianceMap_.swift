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
    let w = 128
    var vertices: [Vertex] = [
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(1.0, 0.0, 0.0, 1)),
    ]

    init() {
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])!
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: w, height: w / 2), label: "irradianceMap")
        pipelineState = Descriptor.createIrradianceMapPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
    }
}

class PrefilterEnvMap {
    var texture: MTLTexture!
    var renderPassDescriptor = MTLRenderPassDescriptor()
    var pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    private let w = 2048
    private let minMipmapWidth = 32
    var vertices: [Vertex] = [
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(1.0, 0.0, 0.0, 1)),
    ]
    var mipMaps: [MTLTexture] = []
    var renderPassDescriptors: [MTLRenderPassDescriptor] = []
    var mipMapCount = 0

    init() {
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])!
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: w, height: w / 2), mipmapped: true)
        pipelineState = Descriptor.createPreFilterEnvMapPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
        generateTextureForMipmaps(w)
    }

    func generateTextureForMipmaps(_: Int) {
        var width = w
        while width >= minMipmapWidth {
            let texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: width, height: width / 2))
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
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(1.0, 0.0, 0.0, 1)),
    ]

    init() {
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])!
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: 512, height: 512))
        pipelineState = Descriptor.createDFGLUTPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
    }
}

class DeferredRenderer: DFGLut {
    override init() {
        super.init()
        pipelineState = Descriptor.createDeferredRendererPipelineState()
    }
}

class PolygonLight {
    var pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    var vertices: [Vertex] = [
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(-1, 1, 0), color: Float4(0.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0.0, 1)),
        Vertex(position: Float3(1, 1, 0), color: Float4(1.0, 1.0, 0, 1)),
        Vertex(position: Float3(-1, -1, 0), color: Float4(0.0, 0.0, 0.0, 1)),
        Vertex(position: Float3(1, -1, 0), color: Float4(1.0, 0.0, 0.0, 1)),
    ]

    init(vertices: [Float3]) {
        self.vertices = [
            Vertex(position: vertices[0], color: Float4(0.0, 0.0, 0.0, 1)),
            Vertex(position: vertices[1], color: Float4(0.0, 1.0, 0.0, 1)),
            Vertex(position: vertices[3], color: Float4(1.0, 1.0, 0.0, 1)),
            Vertex(position: vertices[1], color: Float4(1.0, 1.0, 0, 1)),
            Vertex(position: vertices[2], color: Float4(0.0, 0.0, 0.0, 1)),
            Vertex(position: vertices[3], color: Float4(1.0, 0.0, 0.0, 1)),
        ]
        let device = Device.sharedDevice.device!
        vertexBuffer = device.makeBuffer(bytes: self.vertices, length: MemoryLayout<Vertex>.stride * self.vertices.count, options: [])!
        pipelineState = Descriptor.createLightPipelineState()
    }
}
