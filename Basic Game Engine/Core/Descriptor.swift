//
//  Descriptor.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 16/02/21.
//

import MetalKit

class Descriptor {
    static func build2DTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String = "texture", mipmapped: Bool = false) -> MTLTexture {
        let device = Device.sharedDevice.device!
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: mipmapped)
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
    
    static func build3DTexture(dim: Int, label: String = "3D texture") -> MTLTexture {
        let device = Device.sharedDevice.device!
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.width = dim
        textureDescriptor.height = dim
        textureDescriptor.depth = dim
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { fatalError("Could not make texture") }
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
    
    func setupColorAttachment(_ texture: MTLTexture, _ position: Int = 0) {
        colorAttachments[position].texture = texture
        colorAttachments[position].loadAction = .clear
        colorAttachments[position].storeAction = .store
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
    
    static func createPreFilterEnvMapPipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float;
        descriptor.vertexFunction = Device.sharedDevice.library?.makeFunction(name: "preFilterEnvMapVertexShader")
        descriptor.fragmentFunction = Device.sharedDevice.library?.makeFunction(name: "preFilterEnvMapFragmentShader")
        descriptor.vertexDescriptor = Descriptor.getSimpleVertexDescriptor()
        do {
            return try Device.sharedDevice.device!.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    static func createDFGLUTPipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float;
        descriptor.vertexFunction = Device.sharedDevice.library?.makeFunction(name: "DFGVertexShader")
        descriptor.fragmentFunction = Device.sharedDevice.library?.makeFunction(name: "DFGFragmentShader")
        descriptor.vertexDescriptor = Descriptor.getSimpleVertexDescriptor()
        do {
            return try Device.sharedDevice.device!.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    static func createLightPipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = Constants.pixelFormat;
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = Device.sharedDevice.library?.makeFunction(name: "lightVertexShader")
        descriptor.fragmentFunction = Device.sharedDevice.library?.makeFunction(name: "lightFragmentShader")
        descriptor.vertexDescriptor = Descriptor.getSimpleVertexDescriptor()
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
        descriptor.vertexDescriptor = Descriptor.getSimpleVertexDescriptor()
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

extension Descriptor {
    static func getSimpleVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float3>.size
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        return vertexDescriptor
    }
}
