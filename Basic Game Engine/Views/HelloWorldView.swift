//
//  HelloWorldView.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit
import Cocoa

typealias Float3 = SIMD3<Float>
typealias Float4 = SIMD4<Float>

struct Vertex {
    var position: Float3
    var color: Float4
}

struct Uniforms {
    var MVPmatrix: Matrix4
}

class HelloWorldView: MTKView {
    var commandQueue: MTLCommandQueue?
    var renderPipelineStatus: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    let pixelFormat: MTLPixelFormat = .bgra8Unorm
    
    var deltaTime = 0.0
    var startTime = 0.0
    var time = 0.0
    let P = Matrix4.perspective(fov: (MathConstants.PI.rawValue/3), aspect: 800.0/600, nearDist: 0.5, farDist: 100)
    let cam = Camera(position: Float3(0, 0, 5), target: Float3(0, 0, 0))
    var vertices: [Vertex] = [
        Vertex(position: Float3(-0.5, -0.5, 0), color: Float4(0.17, 0.32, 0.54, 1)),
        Vertex(position: Float3(0, 0.5, 0), color: Float4(0.3, 0.5, 0.7, 1)),
        Vertex(position: Float3(0.5, -0.5, 0), color: Float4(0.2, 0.6, 0.4, 1)),
        Vertex(position: Float3(0.5, 0.5, 0), color: Float4(0.7, 0.2, 1, 1)),
        Vertex(position: Float3(0, 0.5, 0), color: Float4(0.3, 0.3, 0.7, 1)),
        Vertex(position: Float3(0.5, -0.5, 0), color: Float4(0.42, 0.1, 0.4, 1))
    ]
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.device = MTLCreateSystemDefaultDevice()
        clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        colorPixelFormat = pixelFormat
        commandQueue = device?.makeCommandQueue()
        createRenderPipelineState()
        createBuffers()
        startTime = CACurrentMediaTime()
    }
    
    func createRenderPipelineState() {
        let library = device?.makeDefaultLibrary()
        let vertexShader = library?.makeFunction(name: "basicVertexShader")
        let fragmentShader = library?.makeFunction(name: "basicFragmentShader")
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float3>.size
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.vertexFunction = vertexShader
        renderPipelineDescriptor.fragmentFunction = fragmentShader
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            try renderPipelineStatus = device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch let error as NSError {
            print(error)
        }
    }
    
    func createBuffers() {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride*vertices.count, options: [])
    }
    
    func updateUniformBuffer() {
        let cam = Camera()
    //    cam.position = Float3(Float(5 * sin(time)), 1, Float(5 * cos(time)))
        let V = cam.lookAtMatrix
        uniformBuffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        let PV = P*V
        let bufferPointer = uniformBuffer?.contents()
        var u = Uniforms(MVPmatrix: PV)
        memcpy(bufferPointer, &u, MemoryLayout<Uniforms>.stride)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        updateUniformBuffer()
        guard let drawable = currentDrawable, let renderPassDescriptor = currentRenderPassDescriptor, let renderPipelineStatus = renderPipelineStatus else { return }
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        deltaTime = CACurrentMediaTime() - startTime - time
        time = time + deltaTime
        print("FPS: \(1/deltaTime)")
    }
}
