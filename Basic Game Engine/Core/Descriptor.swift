//
//  Descriptor.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 16/02/21.
//

import MetalKit

class Descriptor {
    static func build2DTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String = "texture") -> MTLTexture {
        let device = Device.sharedDevice.device!
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor) else { fatalError("Could not make texture") }
        texture.label = label
        return texture
    }
    
    static func buildTextureCube(size: Int, label: String = "") -> MTLTexture {
        let device = Device.sharedDevice.device!
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: size, mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor) else { fatalError("Could not make texture") }
        texture.label = label
        return texture
    }
}

extension MTLRenderPassDescriptor {
    func setupDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    }
    
    func setupColorAttachment(_ texture: MTLTexture) {
        colorAttachments[0].texture = texture
        colorAttachments[0].loadAction = .load
        colorAttachments[0].storeAction = .store
    }
}

extension Descriptor {
    static func createShadowPipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[0].pixelFormat = .invalid
        descriptor.vertexFunction = Device.sharedDevice.library?.makeFunction(name: "shadowVertexShader")
        descriptor.fragmentFunction = nil
        descriptor.vertexDescriptor = MeshManager.getVertexDescriptor()
        do {
            return try Device.sharedDevice.device!.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    static func createIrradianceMapPipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float;
        descriptor.vertexFunction = Device.sharedDevice.library?.makeFunction(name: "irradianceMapVertexShader")
        descriptor.fragmentFunction = Device.sharedDevice.library?.makeFunction(name: "irradianceMapFragmentShader")
        descriptor.vertexDescriptor = MeshManager.getVertexDescriptor()
        do {
            return try Device.sharedDevice.device!.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
}

/*
let textureLoader = MTKTextureLoader(device: device!)
let options_: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
baseColorTexture = try? textureLoader.newTexture(name: "legoMan", scaleFactor: 1.0, bundle: nil, options: options_)
let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.normalizedCoordinates = true
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
self.samplerState = device?.makeSamplerState(descriptor: samplerDescriptor)!
 */

class IrradianceMap {
    var texture: MTLTexture!
    var renderPassDescriptor = MTLRenderPassDescriptor()
    var pipelineState: MTLRenderPipelineState
    
    init() {
        texture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: 1024, height: 1024));
        pipelineState = Descriptor.createIrradianceMapPipelineState()
        renderPassDescriptor.setupColorAttachment(texture)
    }
}
