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
            let helmet = GameObject(modelName: Models.helmet)
            helmet.transform.translate(Float3(2, 0, 0))
            let helmet2 = GameObject(modelName: Models.helmet)
            helmet2.transform.translate(Float3(-2, 0, 0))
            return [helmet, helmet2]
        }
    }
}

class Scene: NSObject {
    var name = "Game Scene"
    var gameObjects: [GameObject] = []
    let P = Matrix4.perspective(fov: (MathConstants.PI.rawValue/3), aspect: 800.0/600, nearDist: 0.5, farDist: 500)
    let timer = GameTimer.sharedTimer
    let camera = Camera(position: Float3(0, 0, 10), target: Float3(0, 0, 0))
    
    var nodes = [Node]()
    let textureLoader: MTKTextureLoader
    let device = Device.sharedDevice.device
    
    init(_ createGameObjects: ()->[GameObject]) {
        textureLoader = MTKTextureLoader(device: device!)
        super.init()
        gameObjects = createGameObjects()
        timer.startTime = CACurrentMediaTime()
        
    //    updateUniformBuffer()
    }
}

extension Scene: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        timer.updateTime()
        render(view)
        camera.moveCam()
    }
}

extension Scene {
    func getUniformData(_ M: Matrix4 = Matrix4(1.0)) -> Uniforms {
        return Uniforms(M: M, V: camera.lookAtMatrix, P: P)
    }
    
    func render(_ view: MTKView) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        for gameObject in gameObjects {
            if let renderPipelineStatus = gameObject.renderPipelineState, let mesh_ = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
                var u = getUniformData(gameObject.transform.modelMatrix)
                renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
                
                for mesh in mesh_.meshes {
                    let vertexBuffer = mesh.vertexBuffers.first!
                    renderCommandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                    for submesh in mesh.submeshes {
                        let indexBuffer = submesh.indexBuffer
                        renderCommandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
                    }
                }
            }
        }
        renderCommandEncoder?.endEncoding()
        guard let drawable = view.currentDrawable else { return }
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
