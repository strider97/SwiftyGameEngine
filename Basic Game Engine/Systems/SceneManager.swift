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
            let planet = GameObject(modelName: Models.planet)
            planet.transform.translate(Float3(0, -0.2, 0))
            return [planet]
        }
    }
}

class Scene: NSObject {
    var name = "Game Scene"
    var gameObjects: [GameObject] = []
    let P = Matrix4.perspective(fov: (MathConstants.PI.rawValue/3), aspect: 800.0/600, nearDist: 0.01, farDist: 500)
    let timer = GameTimer.sharedTimer
    let camera = Camera(position: Float3(0, 0, 10), target: Float3(0, 0, 0))
    
    let device = Device.sharedDevice.device
    var depthStencilState: MTLDepthStencilState?
    var baseColorTexture: MTLTexture?
    var samplerState: MTLSamplerState!
    
    init(_ createGameObjects: ()->[GameObject]) {
        super.init()
        gameObjects = createGameObjects()
        timer.startTime = CACurrentMediaTime()
        depthStencilState = buildDepthStencilState(device: device!)
        
        let textureLoader = MTKTextureLoader(device: device!)
        let options_: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
        baseColorTexture = try? textureLoader.newTexture(name: "planet", scaleFactor: 1.0, bundle: nil, options: options_)
        let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.normalizedCoordinates = true
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
        self.samplerState = device?.makeSamplerState(descriptor: samplerDescriptor)!
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
        return Uniforms(M: M, V: camera.lookAtMatrix, P: P, eye: camera.position)
    }
    
    func render(_ view: MTKView) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setFragmentTexture(baseColorTexture, index: 0)
        renderCommandEncoder?.setFragmentSamplerState(samplerState, index: 0)
        for gameObject in gameObjects {
            if let renderPipelineStatus = gameObject.renderPipelineState, let mesh_ = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
                var u = getUniformData(gameObject.transform.modelMatrix)
                renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
                
                for mesh in mesh_.meshes {
                    let vertexBuffer = mesh.vertexBuffers.first!
                    renderCommandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                    for submesh in mesh.submeshes {
                        renderCommandEncoder?.drawIndexedPrimitives(type:submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
                    }
                }
            }
        }
        renderCommandEncoder?.endEncoding()
        guard let drawable = view.currentDrawable else { return }
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState? {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
}
