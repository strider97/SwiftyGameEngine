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
    static let W: Float = 1280
    static let H: Float = 720
    final let P = Matrix4(projectionFov: (MathConstants.PI.rawValue/3), near: 0.01, far: 500, aspect: Scene.W/Scene.H)
    final let orthoGraphicP = Matrix4(orthoLeft: -10, right: 10, bottom: -10, top: 10, near: 0.01, far: 20)
    final let timer = GameTimer.sharedTimer
    final var camera: Camera!
    final let device = Device.sharedDevice.device
    final var depthStencilState: MTLDepthStencilState?
    var skybox: Skybox!
    var shadowTexture: MTLTexture!
    var shadowDescriptor = MTLRenderPassDescriptor()
    var shadowPipelineState: MTLRenderPipelineState?
    var irradianceMap = IrradianceMap()
 //   var samplerState: MTLSamplerState!
    var firstDraw = true
    
    override init() {
        super.init()
        camera = getCamera()
        skybox = getSkybox()
        timer.startTime = Float(CACurrentMediaTime())
        depthStencilState = buildDepthStencilState(device: device!)
        gameObjects = getGameObjects()
        addPhysics()
        addBehaviour()
        createShadowTexture()
    }
    
    func getGameObjects() -> [GameObject] {[]}
    func addPhysics() {}
    func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 10), target: Float3(0, 0, 0))
    }
    func getSkybox() -> Skybox {
        return Skybox(textureName: "park")
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
        if mouse.x < Self.W && mouse.y < Self.H && mouse.x > 0.0 && mouse.y > 0.0 {
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
        v[0][3] = 0; v[1][3] = 0; v[2][3] = 0
        v[3][3] = 1; v[3][0] = 0; v[3][1] = 0
        v[3][2] = 0
        return Uniforms(M: M, V: v, P: P, eye: camera.position)
    }
    
    func getFarShadowUniformData(_ M: Matrix4 = Matrix4(1.0)) -> Uniforms {
        return Uniforms(M: M, V: camera.lookAtMatrix, P: orthoGraphicP, eye: camera.position)
    }
    
    func render(_ view: MTKView) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = Device.sharedDevice.commandQueue?.makeCommandBuffer()
        
        if firstDraw {
            let irradianceMapCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: irradianceMap.renderPassDescriptor)
            irradianceMapCommandEncoder?.setCullMode(.none)
            drawIrradianceMap(renderCommandEncoder: irradianceMapCommandEncoder)
            irradianceMapCommandEncoder?.endEncoding()
        }
        let shadowCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: shadowDescriptor)
        shadowCommandEncoder?.setDepthStencilState(depthStencilState)
        shadowCommandEncoder?.setCullMode(.none)
        drawGameObjects(renderCommandEncoder: shadowCommandEncoder, shadowPass: true)
        shadowCommandEncoder?.endEncoding()
        
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setCullMode(.front)
        drawGameObjects(renderCommandEncoder: renderCommandEncoder)
        drawSkybox(renderCommandEncoder: renderCommandEncoder)
        renderCommandEncoder?.endEncoding()
        
        firstDraw = false
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
    
    func createShadowTexture() {
        shadowTexture = Descriptor.build2DTexture(pixelFormat: .depth32Float, size: CGSize(width: Int(Self.W), height: Int(Self.W)))
        shadowDescriptor.setupDepthAttachment(texture: shadowTexture)
        shadowPipelineState = Descriptor.createShadowPipelineState()
    }
    
    func drawGameObjects(renderCommandEncoder: MTLRenderCommandEncoder?, shadowPass: Bool = false) {
        for gameObject in gameObjects {
            if let renderPipelineStatus = shadowPass ? shadowPipelineState : gameObject.renderPipelineState, let mesh_ = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)
                var u = shadowPass ? getFarShadowUniformData(gameObject.transform.modelMatrix) : getUniformData(gameObject.transform.modelMatrix)
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
        renderCommandEncoder?.setFragmentTexture(irradianceMap.texture, index: 3)
        let submesh = skybox.mesh.submeshes[0]
        renderCommandEncoder?.setFragmentSamplerState(skybox.samplerState, index: 0)
        renderCommandEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
    }
    
    func drawIrradianceMap(renderCommandEncoder: MTLRenderCommandEncoder?) {
        renderCommandEncoder?.setRenderPipelineState(irradianceMap.pipelineState)
        renderCommandEncoder?.setVertexBuffer(irradianceMap.vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.setFragmentTexture(skybox.texture, index: 3)
        renderCommandEncoder?.setFragmentSamplerState(skybox.samplerState, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: irradianceMap.vertices.count)
    }
    
    func updateGameObjects() {
        for gameObject in gameObjects {
            for behaviour in gameObject.behaviours {
                behaviour.update()
            }
        }
    }
}
