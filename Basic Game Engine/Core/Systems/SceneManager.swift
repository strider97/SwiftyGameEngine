//
//  SceneManager.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class SceneManager {
    static let sharedManager = SceneManager()
    var currentScene: Scene!
    init () {
        currentScene = BasicScene()
    }
    func loadScene(scene: Scene) {
        currentScene = scene
    }
}

class Scene: NSObject {
    var name = "Game Scene"
    var gameObjects: [GameObject] = []
    static let W:Float = 1280
    static let H:Float = 720
    final let P = Matrix4(projectionFov: (MathConstants.PI.rawValue/3), near: 0.01, far: 500, aspect: Scene.W/Scene.H)
    final let timer = GameTimer.sharedTimer
    final var camera: Camera!
    final let device = Device.sharedDevice.device
    final var depthStencilState: MTLDepthStencilState?
    var skybox: Skybox!
 //   var samplerState: MTLSamplerState!
    
    override init() {
        super.init()
        camera = getCamera()
        skybox = getSkybox()
        timer.startTime = Float(CACurrentMediaTime())
        depthStencilState = buildDepthStencilState(device: device!)
        gameObjects = getGameObjects()
        addPhysics()
        addBehaviour()
        
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
    }
    
    func getGameObjects() -> [GameObject] {[]}
    func addPhysics() {}
    func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 10), target: Float3(0, 0, 0))
    }
    func getSkybox() -> Skybox {
        return Skybox(textureName: "kiara")
    }
    func addBehaviour() {}
}

extension Scene: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        timer.updateTime()
        camera.moveCam()
        let p = view.window!.mouseLocationOutsideOfEventStream
        let mouse = Float2(Float(p.x), Float(p.y))
        if mouse.x < Scene.W && mouse.y < Scene.H && mouse.x > 0.0 && mouse.y > 0.0 {
            if mouse != Input.sharedInput.mousePosition {
                Input.sharedInput.updateMousePosition(pos: mouse)
                if Input.sharedInput.mouseClicked {
                    camera.rotateCam()
                }
            }
        }
        updateGameObjects()
        render(view)
    }
}

extension Scene {
    func getUniformData(_ M: Matrix4 = Matrix4(1.0)) -> Uniforms {
        return Uniforms(M: M, V: camera.lookAtMatrix, P: P, eye: camera.position)
    }
    
    func getSkyboxUniformData() -> Uniforms {
        let M = Matrix4(1.0)
        var v = camera.lookAtMatrix
        v[0][3] = 0
        v[1][3] = 0
        v[2][3] = 0
        v[3][3] = 1
        v[3][0] = 0
        v[3][1] = 0
        v[3][2] = 0
        return Uniforms(M: M, V: v, P: P, eye: camera.position)
    }
    
    func render(_ view: MTKView) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
    //    renderCommandEncoder?.setFragmentSamplerState(samplerState, index: 0)
        
        drawGameObjects(renderCommandEncoder: renderCommandEncoder)
        drawSkybox(renderCommandEncoder: renderCommandEncoder)
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
    
    func drawGameObjects(renderCommandEncoder: MTLRenderCommandEncoder?) {
        for gameObject in gameObjects {
            if let renderPipelineStatus = gameObject.renderPipelineState, let mesh_ = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
                var u = getUniformData(gameObject.transform.modelMatrix)
                renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
                
       //         print(mesh_.meshes.map{$0.name}, mesh_.mdlMeshes.map{$0.name})
                for (mesh, meshNodes) in mesh_.meshNodes {
                    for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                        renderCommandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex)
                    }
                    for meshNode in meshNodes {
                        // add material through uniforms
                        var material = ShaderMaterial(baseColor: meshNode.material.baseColor)
                        renderCommandEncoder?.setFragmentBytes(&material, length: MemoryLayout<ShaderMaterial>.size, index: 0)
                        let submesh = meshNode.mesh
                        renderCommandEncoder?.drawIndexedPrimitives(type:submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
                    }
                }
            }
        }
    }
    
    func drawSkybox(renderCommandEncoder: MTLRenderCommandEncoder?) {
        renderCommandEncoder?.setDepthStencilState(skybox.depthStencilState)
        renderCommandEncoder?.setRenderPipelineState(skybox.pipelineState)
        var u = getSkyboxUniformData()
        renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        renderCommandEncoder?.setVertexBuffer(skybox.mesh.vertexBuffers[0].buffer,
                                              offset: 0, index: 0)
        renderCommandEncoder?.setFragmentTexture(skybox.texture, index: 3)
        let submesh = skybox.mesh.submeshes[0]
        renderCommandEncoder?.setFragmentSamplerState(skybox.samplerState, index: 0)
        renderCommandEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
    }
    
    func updateGameObjects() {
        for gameObject in gameObjects {
            for behaviour in gameObject.behaviours {
                behaviour.update()
            }
        }
    }
}
