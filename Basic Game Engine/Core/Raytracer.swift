//
//  Raytracer.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 27/05/21.
//

import MetalKit
import MetalPerformanceShaders

class Raytracer {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var library: MTLLibrary
    
    var rayPipeline: MTLComputePipelineState!
    var rayBuffer: MTLBuffer!
    var shadowRayBuffer: MTLBuffer!
    
    var shadePipelineState: MTLComputePipelineState!
    var accumulatePipeline: MTLComputePipelineState!
    var accumulationTarget: MTLTexture!
    var accelerationStructure: MPSTriangleAccelerationStructure!
    var shadowPipeline: MTLComputePipelineState!
    
    var vertexPositionBuffer: MTLBuffer!
    var vertexNormalBuffer: MTLBuffer!
    var vertexColorBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var randomBuffer: MTLBuffer!
    var intersectionBuffer: MTLBuffer!
    let intersectionStride =
      MemoryLayout<MPSIntersectionDistancePrimitiveIndexCoordinates>.stride
    
    var intersector: MPSRayIntersector!
    let rayStride =
      MemoryLayout<MPSRayOriginMinDistanceDirectionMaxDistance>.stride
        + MemoryLayout<Float3>.stride
    
    let maxFramesInFlight = 3
    let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 255) & ~255
    var semaphore: DispatchSemaphore!
    var size = CGSize.zero
    var randomBufferOffset = 0
    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var frameIndex: uint = 0
    var renderTarget: MTLTexture!
    weak var camera: Camera!
    
    lazy var vertexDescriptor: MDLVertexDescriptor = {
      let vertexDescriptor = MDLVertexDescriptor()
      vertexDescriptor.attributes[0] =
        MDLVertexAttribute(name: MDLVertexAttributePosition,
                           format: .float3,
                           offset: 0, bufferIndex: 0)
      vertexDescriptor.attributes[1] =
        MDLVertexAttribute(name: MDLVertexAttributeNormal,
                           format: .float2,
                           offset: 0, bufferIndex: 1)
      vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float3>.stride)
      vertexDescriptor.layouts[1] = MDLVertexBufferLayout(stride: MemoryLayout<Float3>.stride)
      return vertexDescriptor
    }()
    
    var vertices: [Float3] = []
    var normals: [Float3] = []
    var colors: [Float3] = []
    
    init(metalView: MTKView) {
        device = Device.sharedDevice.device!
        semaphore = DispatchSemaphore.init(value: maxFramesInFlight)
        library = Device.sharedDevice.library!
        commandQueue = Device.sharedDevice.commandQueue!
        buildPipelines(view: metalView)
        createScene()
        createBuffers()
        buildIntersector()
        buildAccelerationStructure()
    }
    
    func buildAccelerationStructure() {
      accelerationStructure =
        MPSTriangleAccelerationStructure(device: device)
      accelerationStructure?.vertexBuffer = vertexPositionBuffer
      accelerationStructure?.triangleCount = vertices.count / 3
      accelerationStructure?.rebuild()
    }
    
    func buildIntersector() {
      intersector = MPSRayIntersector(device: device)
      intersector?.rayDataType = .originMinDistanceDirectionMaxDistance
      intersector?.rayStride = rayStride
    }
    
    func buildPipelines(view: MTKView) {
      let vertexFunction = library.makeFunction(name: "vertexShaderRT")
      let fragmentFunction = library.makeFunction(name: "fragmentShader")
      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.sampleCount = view.sampleCount
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
      let computeDescriptor = MTLComputePipelineDescriptor()
      computeDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
      
      do {
        computeDescriptor.computeFunction = library.makeFunction(
          name: "shadowKernel")
        shadowPipeline = try device.makeComputePipelineState(
          descriptor: computeDescriptor,
          options: [],
          reflection: nil)
        
        computeDescriptor.computeFunction = library.makeFunction(
          name: "shadeKernel")
        shadePipelineState = try device.makeComputePipelineState(
          descriptor: computeDescriptor,
          options: [],
          reflection: nil)
        
        computeDescriptor.computeFunction = library.makeFunction(
          name: "accumulateKernel")
        accumulatePipeline = try device.makeComputePipelineState(
          descriptor: computeDescriptor,
          options: [],
          reflection: nil)
        
        computeDescriptor.computeFunction = library.makeFunction(
          name: "primaryRays")
        rayPipeline = try device.makeComputePipelineState(
          descriptor: computeDescriptor,
          options: [],
          reflection: nil)
        
    //    renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      } catch {
        print(error.localizedDescription)
      }
    }
    
    func createScene() {
        loadAsset(name: "sponza")
    }
    
    
    func createBuffers() {
      let uniformBufferSize = alignedUniformsSize * maxFramesInFlight

      let options: MTLResourceOptions = {
        #if os(iOS)
        return .storageModeShared
        #else
        return .storageModeManaged
        #endif
      } ()
      
      uniformBuffer = device.makeBuffer(length: uniformBufferSize, options: options)
      randomBuffer = device.makeBuffer(length: 256 * MemoryLayout<Float2>.stride * maxFramesInFlight, options: options)
      vertexPositionBuffer = device.makeBuffer(bytes: &vertices, length: vertices.count * MemoryLayout<Float3>.stride, options: options)
      vertexColorBuffer = device.makeBuffer(bytes: &colors, length: colors.count * MemoryLayout<Float3>.stride, options: options)
      vertexNormalBuffer = device.makeBuffer(bytes: &normals, length: normals.count * MemoryLayout<Float3>.stride, options: options)
    }
    
    func update() {
      GameTimer.sharedTimer.updateTime()
      updateUniforms()
   //   updateRandomBuffer()
      uniformBufferIndex = (uniformBufferIndex + 1) % maxFramesInFlight
    }
    
    func updateUniforms() {
      uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
      let pointer = uniformBuffer!.contents().advanced(by: uniformBufferOffset)
      let uniforms = pointer.bindMemory(to: Uniforms_.self, capacity: 1)
      
        var camera = Camera_()
    //    camera.position = float3(8*sin(GameTimer.sharedTimer.time/10.0), 1.0, 8*cos(GameTimer.sharedTimer.time/10.0))
        camera.position = self.camera.position
        camera.forward = self.camera.front
        camera.right = self.camera.right
        camera.up = self.camera.up
      
        let fieldOfView = MathConstants.PI.rawValue/3
      let aspectRatio = Float(size.width) / Float(size.height)
      let imagePlaneHeight = tanf(fieldOfView / 2.0)
      let imagePlaneWidth = aspectRatio * imagePlaneHeight
      
  //    camera.right *= imagePlaneWidth
  //    camera.up *= imagePlaneHeight
        print(camera.right!)
      var light = AreaLight()
      light.position = Float3(0.0, 1.98, 7.0)
      light.forward = Float3(0.0, -1.0, 0.0)
      light.right = Float3(0.25, 0.0, 0.0)
      light.up = Float3(0.0, 0.0, 0.25)
      light.color = Float3(4.0, 4.0, 4.0)
      
      uniforms.pointee.camera = camera
      uniforms.pointee.light = light
      
      uniforms.pointee.width = uint(size.width)
      uniforms.pointee.height = uint(size.height)
      uniforms.pointee.blocksWide = ((uniforms.pointee.width) + 15) / 16
      uniforms.pointee.frameIndex = frameIndex
      frameIndex += 1
      #if os(OSX)
      uniformBuffer?.didModifyRange(uniformBufferOffset..<(uniformBufferOffset + alignedUniformsSize))
      #endif
    }
 
}


extension Raytracer {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
      self.size = size
      frameIndex = 0
      let renderTargetDescriptor = MTLTextureDescriptor()
      renderTargetDescriptor.pixelFormat = .rgba32Float
      renderTargetDescriptor.textureType = .type2D
      renderTargetDescriptor.width = Int(size.width)
      renderTargetDescriptor.height = Int(size.height)
      renderTargetDescriptor.storageMode = .private
      renderTargetDescriptor.usage = [.shaderRead, .shaderWrite]
      renderTarget = device.makeTexture(descriptor: renderTargetDescriptor)
      
      let rayCount = Int(size.width * size.height)
      rayBuffer = device.makeBuffer(length: rayStride * rayCount,
                                    options: .storageModePrivate)
      shadowRayBuffer = device.makeBuffer(length: rayStride * rayCount,
                                          options: .storageModePrivate)
      
      accumulationTarget = device.makeTexture(
        descriptor: renderTargetDescriptor)
      
      intersectionBuffer = device.makeBuffer(
        length: intersectionStride * rayCount,
        options: .storageModePrivate)
    }
    
    func draw(in view: MTKView, commandBuffer: MTLCommandBuffer?) {
   //   print(frameIndex, size.width, size.height, size.width * size.height * 6)
      semaphore.wait()
      guard let commandBuffer = commandBuffer else {
        return
      }
      commandBuffer.addCompletedHandler { [weak self] cb in
        self?.semaphore.signal()
      }
      update()
      
      // MARK: generate rays
      let width = Int(size.width)
      let height = Int(size.height)
      let threadsPerGroup = MTLSizeMake(16, 16, 1)
      let threadGroups = MTLSizeMake(
          (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
          (height + threadsPerGroup.height - 1) / threadsPerGroup.height, 1)
      var computeEncoder = commandBuffer.makeComputeCommandEncoder()
      computeEncoder?.label = "Generate Rays"
      computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset,
                                index: 0)
      computeEncoder?.setBuffer(rayBuffer, offset: 0, index: 1)
      computeEncoder?.setBuffer(randomBuffer, offset: randomBufferOffset,
                                index: 2)
      computeEncoder?.setTexture(renderTarget, index: 0)
      computeEncoder?.setComputePipelineState(rayPipeline)
      computeEncoder?.dispatchThreadgroups(threadGroups,
                                           threadsPerThreadgroup: threadsPerGroup)
      computeEncoder?.endEncoding()
      
      for _ in 0..<3 {
        // MARK: generate intersections between rays and model triangles
        intersector?.intersectionDataType = .distancePrimitiveIndexCoordinates
        intersector?.encodeIntersection(
          commandBuffer: commandBuffer,
          intersectionType: .nearest,
          rayBuffer: rayBuffer,
          rayBufferOffset: 0,
          intersectionBuffer: intersectionBuffer,
          intersectionBufferOffset: 0,
          rayCount: width * height,
          accelerationStructure: accelerationStructure)
        
        // MARK: shading
        
        computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder?.label = "Shading"
        computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset,
                                  index: 0)
        computeEncoder?.setBuffer(rayBuffer, offset: 0, index: 1)
        computeEncoder?.setBuffer(shadowRayBuffer, offset: 0, index: 2)
        computeEncoder?.setBuffer(intersectionBuffer, offset: 0, index: 3)
        computeEncoder?.setBuffer(vertexColorBuffer, offset: 0, index: 4)
        computeEncoder?.setBuffer(vertexNormalBuffer, offset: 0, index: 5)
        computeEncoder?.setBuffer(randomBuffer, offset: randomBufferOffset,
                                  index: 6)
        computeEncoder?.setTexture(renderTarget, index: 0)
        computeEncoder?.setComputePipelineState(shadePipelineState!)
        computeEncoder?.dispatchThreadgroups(
          threadGroups,
          threadsPerThreadgroup: threadsPerGroup)
        computeEncoder?.endEncoding()
        
        // MARK: shadows
        intersector?.label = "Shadows Intersector"
        intersector?.intersectionDataType = .distance
        intersector?.encodeIntersection(
          commandBuffer: commandBuffer,
          intersectionType: .any,
          rayBuffer: shadowRayBuffer,
          rayBufferOffset: 0,
          intersectionBuffer: intersectionBuffer,
          intersectionBufferOffset: 0,
          rayCount: width * height,
          accelerationStructure: accelerationStructure)
        
        computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder?.label = "Shadows"
        computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset,
                                  index: 0)
        computeEncoder?.setBuffer(shadowRayBuffer, offset: 0, index: 1)
        computeEncoder?.setBuffer(intersectionBuffer, offset: 0, index: 2)
        computeEncoder?.setTexture(renderTarget, index: 0)
        computeEncoder?.setComputePipelineState(shadowPipeline!)
        computeEncoder?.dispatchThreadgroups(
          threadGroups,
          threadsPerThreadgroup: threadsPerGroup)
        computeEncoder?.endEncoding()
        
        
      }
      // MARK: accumulation
      
      computeEncoder = commandBuffer.makeComputeCommandEncoder()
      computeEncoder?.label = "Accumulation"
      computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset,
                                index: 0)
      computeEncoder?.setTexture(renderTarget, index: 0)
      computeEncoder?.setTexture(accumulationTarget, index: 1)
      computeEncoder?.setComputePipelineState(accumulatePipeline)
      computeEncoder?.dispatchThreadgroups(threadGroups,
                                           threadsPerThreadgroup: threadsPerGroup)
      computeEncoder?.endEncoding()
      
//      guard let descriptor = view.currentRenderPassDescriptor,
//        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
//          descriptor: descriptor) else {
//            return
//      }
//  //    renderEncoder.setRenderPipelineState(renderPipeline!)
//
//      // MARK: draw call
//      renderEncoder.setFragmentTexture(accumulationTarget, index: 0)
//      renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
//      renderEncoder.endEncoding()
//      guard let drawable = view.currentDrawable else {
//        return
//      }
//      commandBuffer.present(drawable)
//      commandBuffer.commit()
    }
  }

extension Raytracer {
  func loadAsset(name: String, position: Float3 = [0, 0, 0], scale: Float = 1) {
    let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")!
    let allocator = MTKMeshBufferAllocator(device: device)
    let asset = MDLAsset(url: assetURL,
                         vertexDescriptor: vertexDescriptor,
                         bufferAllocator: allocator)
    guard let mdlMesh = asset.object(at: 0) as? MDLMesh,
      let mdlSubmeshes = mdlMesh.submeshes as? [MDLSubmesh] else { return }
    let mesh = try! MTKMesh(mesh: mdlMesh, device: device)
    let count = mesh.vertexBuffers[0].buffer.length / MemoryLayout<Float3>.size
    let positionBuffer = mesh.vertexBuffers[0].buffer
    let normalsBuffer = mesh.vertexBuffers[1].buffer
    let normalsPtr = normalsBuffer.contents().bindMemory(to: Float3.self, capacity: count)
    let positionPtr = positionBuffer.contents().bindMemory(to: Float3.self, capacity: count)
    for (mdlIndex, submesh) in mesh.submeshes.enumerated() {
      let indexBuffer = submesh.indexBuffer.buffer
      let offset = submesh.indexBuffer.offset
      let indexPtr = indexBuffer.contents().advanced(by: offset)
      var indices = indexPtr.bindMemory(to: uint.self, capacity: submesh.indexCount)
      for _ in 0..<submesh.indexCount {
        let index = Int(indices.pointee)
        vertices.append(positionPtr[index] * scale + position)
        normals.append(normalsPtr[index])
        indices = indices.advanced(by: 1)
        let mdlSubmesh = mdlSubmeshes[mdlIndex]
        let color: Float3
        if let baseColor = mdlSubmesh.material?.property(with: .baseColor),
           baseColor.type == .float3 {
          color = baseColor.float3Value
        } else {
          color = [1, 0, 0]
        }
        colors.append(color)
      }
    }
  }

}

struct Camera_ {
    var position: Float3!
    var right: Float3!
    var up: Float3!
    var forward: Float3!
}

struct AreaLight {
    var position: Float3!
    var forward: Float3!
    var right: Float3!
    var up: Float3!
    var color: Float3!
}

struct Uniforms_ {
    var width: UInt32!
    var height: UInt32!
    var blocksWide: UInt32!
    var frameIndex: UInt32!
    var camera: Camera_!
    var light: AreaLight!
}
