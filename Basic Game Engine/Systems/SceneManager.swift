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
    init(_ createGameObjects: ()->[GameObject]) {
        gameObjects = createGameObjects()
    }
}

extension Scene: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        for gameObject in gameObjects {
            if let state = gameObject.
            }
            
            renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
            renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderCommandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        deltaTime = CACurrentMediaTime() - startTime - time
        time = time + deltaTime
        print("FPS: \(1/deltaTime)")
    }
}
