//
//  Renderer.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit
typealias Device = MTLDeviceObject

struct ShaderMaterial {
    var baseColor: Float3
    let roughness: Float
    let metallic: Float
    var mipmapCount: Int = 0
}

enum TextureIndex: Int {
    case preFilterEnvMap
    case DFGlut
    case irradianceMap
    case baseColor
    case metallic
    case roughness
    case normalMap
}

class Material {
    var baseColor = Float3(repeating: 1)
    var roughness: Float = 0
    var metallic: Float = 0.8 {
        didSet {
            metallic = max(0.001, metallic)
        }
    }
    var textureSet: TextureSet!
    
    private let library = Device.sharedDevice.library
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
    convenience init(_ material: MDLMaterial?, _ textureLoader: MTKTextureLoader) {
        self.init()
        if let material = material {
            baseColor = material.property(with: .baseColor)?.float3Value ?? Float3(repeating: 1) 
            roughness = material.property(with: .materialIndexOfRefraction)?.floatValue ?? Float(0.1)
            metallic = material.property(with: .emission)?.floatValue ?? Float(0.8)
            textureSet = TextureSet(material: material, textureLoader: textureLoader)
        }
    }
}

class TextureSet {
    var baseColor: MTLTexture!
    var metallic: MTLTexture!
    var roughness: MTLTexture!
    var normalMap: MTLTexture!
//    var normal: MTLTexture?
//    var emissive: MTLTexture?
    static let defaultTexture = getDefautTexture()
    
    func texture(for semantic: MDLMaterialSemantic, in material: MDLMaterial, textureLoader: MTKTextureLoader) -> MTLTexture? {
        guard let materialProperty = material.property(with: semantic) else { return nil }
        /*
        print(material.name)
        print(material.property(with: .baseColor)?.float3Value)
        print(material.property(with: .emission)?.float3Value)
        print(material.property(with: .specular)?.float3Value)
        print(material.property(with: .metallic)?.float3Value)
        print(material.property(with: .roughness)?.float3Value)
        print(material.property(with: .specular)?.float3Value)
        print(material.property(with: .materialIndexOfRefraction)?.float3Value)
        print(material.property(with: .userDefined)?.float3Value)
         */
        guard let sourceTexture = materialProperty.textureSamplerValue?.texture else { return nil }
    //    let wantMips = materialProperty.semantic != .tangentSpaceNormal
        var options: [MTKTextureLoader.Option : Any] = [:]
        if semantic == .baseColor {
            options[.SRGB] = true
        }
        return try? textureLoader.newTexture(texture: sourceTexture, options: options)
    }

    init(material sourceMaterial: MDLMaterial, textureLoader: MTKTextureLoader) {
        baseColor = texture(for: .baseColor, in: sourceMaterial, textureLoader: textureLoader) ?? Self.defaultTexture
        metallic = texture(for: .metallic, in: sourceMaterial, textureLoader: textureLoader) ?? Self.defaultTexture
        roughness = texture(for: .roughness, in: sourceMaterial, textureLoader: textureLoader) ?? Self.defaultTexture
        normalMap = texture(for: .tangentSpaceNormal, in: sourceMaterial, textureLoader: textureLoader)!
    //    emissive = texture(for: .emission, in: sourceMaterial, textureLoader: textureLoader)
    }
    
    static func getDefautTexture() -> MTLTexture {
        let bounds = MTLRegionMake2D(0, 0, 1, 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                  width: bounds.size.width,
                                                                  height: bounds.size.height,
                                                                  mipmapped: false)
        descriptor.usage = .shaderRead
        let defaultTexture = Device.sharedDevice.device!.makeTexture(descriptor: descriptor)!
        let defaultColor: [UInt8] = [ 255, 255, 255, 255 ]
        defaultTexture.replace(region: bounds, mipmapLevel: 0, withBytes: defaultColor, bytesPerRow: 4)
        return defaultTexture
    }
}
