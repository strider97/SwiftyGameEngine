//
//  RenderPipelineState.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class MTLDeviceObject {
    static let sharedDevice = MTLDeviceObject()
    let device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var library: MTLLibrary?
    var commandBuffer: MTLCommandBuffer?
    
    private init () {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        library = device?.makeDefaultLibrary()
        commandBuffer = commandQueue?.makeCommandBuffer()
    }
}

class GBufferData {
    var depth: MTLTexture
    var normal: MTLTexture
    var worldPos: MTLTexture
    var flux: MTLTexture
    var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!
    var renderPipelineState: MTLRenderPipelineState?
    
    init(size: CGSize) {
        depth = Descriptor.build2DTexture(pixelFormat: .depth32Float, size: size)
        normal = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: size)
        worldPos = Descriptor.build2DTexture(pixelFormat: .rgba32Float, size: size)
        flux = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: size)
        buildGBufferRenderPassDescriptor(size: size)
        buildGBufferPipelineState()
    }
    
    func buildGBufferRenderPassDescriptor(size: CGSize) {
        gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        gBufferRenderPassDescriptor.setupColorAttachment(normal, 0)
        gBufferRenderPassDescriptor.setupColorAttachment(worldPos, 1)
        gBufferRenderPassDescriptor.setupColorAttachment(flux, 2)
        gBufferRenderPassDescriptor.setupDepthAttachment(texture: depth)
    }
    
    func buildGBufferPipelineState() {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.colorAttachments[1].pixelFormat = .rgba32Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
        descriptor.vertexFunction = Device.sharedDevice.library!.makeFunction(name: "vertexRSM")
        descriptor.fragmentFunction = Device.sharedDevice.library!.makeFunction(name: "fragmentRSM")
        descriptor.vertexDescriptor = MeshManager.meshManager.vertexDescriptor
        do {
            renderPipelineState = try Device.sharedDevice.device!.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
}
