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
            let mesh = Mesh(vertices: BasicModelsVertices.triangle)
            let renderer = Renderer()
            var gameObjects: [GameObject] = []
            let count = 10.0
            let sqrtCount = Float(sqrt(count))
            for i in 0..<Int(count) {
                let triangle = GameObject(Float3(2.0*Float(i)/sqrtCount, 2.0*Float(i%Int(sqrtCount)), 0.0) + Float3(-sqrtCount, -sqrtCount, 0))
                triangle.addComponent(mesh)
                triangle.addComponent(renderer)
                triangle.createRenderPipelineState(material: renderer.material, vertexDescriptor: mesh.vertexDescriptor)
                gameObjects.append(triangle)
            }
            return gameObjects
        }
    }
}

class Scene: NSObject {
    var name = "Game Scene"
    var gameObjects: [GameObject] = []
    let P = Matrix4.perspective(fov: (MathConstants.PI.rawValue/3), aspect: 800.0/600, nearDist: 0.5, farDist: 500)
    let timer = GameTimer.sharedTimer
    let camera = Camera(position: Float3(0, 0, 10), target: Float3(0, 0, 0))
    
    init(_ createGameObjects: ()->[GameObject]) {
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
        guard let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        for gameObject in gameObjects {
            if let renderPipelineStatus = gameObject.renderPipelineState, let mesh = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
                if mesh.vertices.count*MemoryLayout<Vertex>.size < 4096 {
                    let vertex = mesh.vertices
                    renderCommandEncoder?.setVertexBytes(vertex, length: MemoryLayout<Vertex>.stride*vertex.count, index: 0)
                } else {
                    renderCommandEncoder?.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
                }
                var u = getUniformData(gameObject.transform.modelMatrix)
                renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
                renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertices.count)
            }
        }
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
