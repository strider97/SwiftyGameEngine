//
//  SceneManager.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class SceneManager {
    static let sharedManager = SceneManager()
    let currentScene: Scene
    private init () {
        currentScene = Scene() {
            let triangle = GameObject()
            let mesh = Mesh(vertices: BasicModelsVertices.triangle)
            let renderer = Renderer()
            triangle.addComponent(mesh)
            triangle.addComponent(renderer)
            triangle.createRenderPipelineState(material: renderer.material, vertexDescriptor: mesh.vertexDescriptor)
            return [triangle]
        }
    }
}

class Scene: NSObject {
    var name = "Game Scene"
    var gameObjects: [GameObject] = []
    var uniformBuffer: MTLBuffer?
    let P = Matrix4.perspective(fov: (MathConstants.PI.rawValue/3), aspect: 800.0/600, nearDist: 0.5, farDist: 100)
    
    init(_ createGameObjects: ()->[GameObject]) {
        gameObjects = createGameObjects()
    }
    
    func updateUniformBuffer() {
        let cam = Camera()
    //    cam.position = Float3(Float(5 * sin(time)), 1, Float(5 * cos(time)))
        let V = cam.lookAtMatrix
        uniformBuffer = Device.sharedDevice.device?.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        let PV = P*V
        let bufferPointer = uniformBuffer?.contents()
        var u = Uniforms(MVPmatrix: PV)
        memcpy(bufferPointer, &u, MemoryLayout<Uniforms>.stride)
    }
}

extension Scene: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        updateUniformBuffer()
        guard let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        for gameObject in gameObjects {
            if let renderPipelineStatus = gameObject.renderPipelineState, let mesh = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
                renderCommandEncoder?.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
                renderCommandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertices.count)
            } else {
                print("lol")
            }
        }
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    //    deltaTime = CACurrentMediaTime() - startTime - time
    //    time = time + deltaTime
    //    print("FPS: \(1/deltaTime)")
    }
}
