//
//  File.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 13/02/21.
//

import MetalKit

class Skybox {
    let mesh: MTKMesh
    var texture: MTLTexture?
    var mipmappedTexture: MTLTexture
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?
    var samplerState: MTLSamplerState?

    init(textureName: String) {
        let device = Device.sharedDevice.device!
        let allocator = MTKMeshBufferAllocator(device: device)
        let cube = MDLMesh.newBox(withDimensions: [1, 1, 1], segments: [1, 1, 1], geometryType: .triangles, inwardNormals: true, allocator: allocator)
        do {
            mesh = try MTKMesh(mesh: cube, device: device)
        } catch {
            fatalError("failed to create skybox mesh")
        }
        pipelineState = Self.buildPipelineState(vertexDescriptor: cube.vertexDescriptor)
        depthStencilState = Self.buildDepthStencilState()
        /*
            let sky = MDLSkyCubeTexture(name: nil,
                    channelEncoding: MDLTextureChannelEncoding.uInt8,
                    textureDimensions: [Int32(160), Int32(160)],
                    turbidity: 0,
                    sunElevation: 30,
                    upperAtmosphereScattering: 0,
                    groundAlbedo: 0)
            do {
                let textureLoader = MTKTextureLoader(device: device)
                texture = try textureLoader.newTexture(texture: sky, options: nil)
              } catch {
                fatalError("failed to create skybox texture")
              }
         //   texture = Self.createSkycubeTexture(name: textureName)
            */
        texture = Self.loadHDR(name: textureName)
        samplerState = Self.createSamplerState()
        mipmappedTexture = Descriptor.build2DTexture(pixelFormat: .rgba16Float, size: CGSize(width: texture!.width, height: texture!.height), label: "skyboxMipmapped", mipmapped: true)
    }

    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = Constants.pixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction =
            Device.sharedDevice.library?.makeFunction(name: "skyboxVertexShader")
        descriptor.fragmentFunction =
            Device.sharedDevice.library?.makeFunction(name: "skyboxFragmentShader")
        descriptor.vertexDescriptor =
            MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        do {
            let pipelineState = try Device.sharedDevice.device!.makeRenderPipelineState(descriptor: descriptor)
            return pipelineState
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return Device.sharedDevice.device!.makeDepthStencilState(descriptor: descriptor)
    }

    static func createSkycubeTexture(name: String) -> MTLTexture? {
        let device = Device.sharedDevice.device!
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [:]
        do {
            let textureURL = Bundle.main.url(forResource: name, withExtension: "jpg")!
            let texture = try textureLoader.newTexture(URL: textureURL, options: options)
            return texture
        } catch {
            fatalError("Could not load irradiance map from asset catalog: \(error)")
        }
    }

    static func createSamplerState() -> MTLSamplerState? {
        let device = Device.sharedDevice.device
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device?.makeSamplerState(descriptor: samplerDescriptor)
    }

    static func loadHDR(name: String, fileExtension: String = "hdr") -> MTLTexture? {
        let url = Bundle.main.url(forResource: name, withExtension: fileExtension)!
        let device = Device.sharedDevice.device!
        let cfURLString = url.path as CFString
        guard let cfURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, cfURLString, CFURLPathStyle.cfurlposixPathStyle, false) else {
            fatalError("Failed to create CFURL from: \(url.path)")
        }
        guard let cgImageSource = CGImageSourceCreateWithURL(cfURL, nil) else {
            fatalError("Failed to create CGImageSource")
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            fatalError("Failed to create CGImage")
        }

        print(cgImage.width)
        print(cgImage.height)
        print(cgImage.bitsPerComponent)
        print(cgImage.bytesPerRow)
        print(cgImage.byteOrderInfo)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageByteOrderInfo.order16Little.rawValue
        guard let bitmapContext = CGContext(data: nil,
                                            width: cgImage.width,
                                            height: cgImage.height,
                                            bitsPerComponent: cgImage.bitsPerComponent,
                                            bytesPerRow: cgImage.width * 2 * 4,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo) else { return nil }

        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = cgImage.width
        descriptor.height = cgImage.height
        descriptor.depth = 1
        descriptor.usage = .shaderRead
        descriptor.sampleCount = 1
        descriptor.textureType = .type2D

        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, cgImage.width, cgImage.height), mipmapLevel: 0, withBytes: bitmapContext.data!, bytesPerRow: cgImage.width * 2 * 4)

        return texture
    }
}
