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
        currentScene = SimpleScene()
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
    var preFilterEnvMap = PrefilterEnvMap()
    var dfgLut = DFGLut()
    var irradianceMap = IrradianceMap()
 //   var samplerState: MTLSamplerState!
    var firstDraw = true
    private var exposure: Float = 0.5
    var ltcMat: MTLTexture!
    var ltcMag: MTLTexture!
    var indirectCB: MTLIndirectCommandBuffer!
    
    var lightPolygon: [Float3] = [
        Float3(-6, -1.9, 20),
        Float3(0, 3, 20),
        Float3(6, -1.9, 20),
        Float3(0, 10, 20)
    ]
    
    lazy var lightPolygonInitial: [Float3] = getLightPolygon(size: 1, z: 16, scale: Float2(16, 16))
    
    func getLightPolygon(size: Float, z: Float, scale: Float2 = Float2(repeating: 1.0)) -> [Float3] {
        let size_ = size/2
        return [
            Float3(-size_ * scale.x, 0, z),
            Float3(-size_ * scale.x, 2 * size_ * scale.y, z),
            Float3(size_ * scale.x, 2 * size_ * scale.y, z),
            Float3(size_ * scale.x, 0, z)
        ]
    }
    
    var lightMovementTime: Float {
        GameTimer.sharedTimer.time/2.5
    }
    
    var light: PolygonLight!
    
    override init() {
        super.init()
   //     initializeCommands()
        light = PolygonLight(vertices: lightPolygonInitial)
        camera = getCamera()
        skybox = getSkybox()
        timer.startTime = Float(CACurrentMediaTime())
        depthStencilState = buildDepthStencilState(device: device!)
        gameObjects = getGameObjects()
        Material.heap = Material.buildHeap()
        gameObjects.forEach {
            $0.getComponent(Mesh.self)!.meshNodes.forEach {
                $0.1.forEach {
                    $0.material.initializeTextures()
                }
            }
        }
        addPhysics()
        addBehaviour()
        createShadowTexture()
        createLTCTextures()
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
        updateSceneData()
        updateGameObjects()
        render(view)
    }
}

extension Scene {
    func getUniformData(_ M: Matrix4 = Matrix4(1.0)) -> Uniforms {
        return Uniforms(M: M, V: camera.lookAtMatrix, P: P, eye: camera.position, exposure: exposure)
    }
    
    func getLightUniformData() -> Uniforms {
        var M = Matrix4(1)
        M[3][0] = Float(sin(lightMovementTime) * 20)
        return Uniforms(M: M, V: camera.lookAtMatrix, P: P, eye: camera.position, exposure: exposure)
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
        
        // Generate irradiance maps and DFG lut if first draw
        if firstDraw {
            let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
            blitEncoder?.copy(from: skybox.texture!, sourceSlice: 0, sourceLevel: 0, to: skybox.mipmappedTexture, destinationSlice: 0, destinationLevel: 0, sliceCount: 1, levelCount: 1)
            blitEncoder?.generateMipmaps(for: skybox.mipmappedTexture)
            blitEncoder?.endEncoding()
            
            for i in 0..<preFilterEnvMap.mipMapCount {
                let mipmapEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: preFilterEnvMap.renderPassDescriptors[i])
                drawPrefilterEnvMap(renderCommandEncoder: mipmapEncoder, roughness: Float(i)/Float(preFilterEnvMap.mipMapCount))
                mipmapEncoder?.endEncoding()
            }
            
            let blitCopyEncoder = commandBuffer?.makeBlitCommandEncoder()
            blitCopyEncoder?.generateMipmaps(for: preFilterEnvMap.texture)
            for i in 0..<preFilterEnvMap.mipMapCount {
                blitCopyEncoder?.copy(from: preFilterEnvMap.mipMaps[i], sourceSlice: 0, sourceLevel: 0, to: preFilterEnvMap.texture, destinationSlice: 0, destinationLevel: i, sliceCount: 1, levelCount: 1)
            }
            blitCopyEncoder?.endEncoding()
            
            let dfgCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: dfgLut.renderPassDescriptor)
            drawDFGLUT(renderCommandEncoder: dfgCommandEncoder)
            dfgCommandEncoder?.endEncoding()
            
            let irradianceMapCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: irradianceMap.renderPassDescriptor)
            drawIrradianceMap(renderCommandEncoder: irradianceMapCommandEncoder)
            irradianceMapCommandEncoder?.endEncoding()
            
        //    let textureLoader = MTKTextureLoader(device: device!)
        //    let options_: [MTKTextureLoader.Option : Any] = [.SRGB : false]
        //    dfgLut.texture = try! textureLoader.newTexture(name: "dfglut", scaleFactor: 1.0, bundle: nil, options: options_)
        }
        /*
        let shadowCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: shadowDescriptor)
        shadowCommandEncoder?.setDepthStencilState(depthStencilState)
        shadowCommandEncoder?.setCullMode(.none)
        drawGameObjects(renderCommandEncoder: shadowCommandEncoder, shadowPass: true)
        shadowCommandEncoder?.endEncoding()
        */
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setFragmentTexture(preFilterEnvMap.texture, index: TextureIndex.preFilterEnvMap.rawValue)
        renderCommandEncoder?.setFragmentTexture(dfgLut.texture, index: TextureIndex.DFGlut.rawValue)
        renderCommandEncoder?.setFragmentTexture(irradianceMap.texture, index: TextureIndex.irradianceMap.rawValue)
        renderCommandEncoder?.setFragmentTexture(ltcMat, index: TextureIndex.ltc_mat.rawValue)
        renderCommandEncoder?.setFragmentTexture(ltcMag, index: TextureIndex.ltc_mag.rawValue)
        renderCommandEncoder?.setCullMode(.none)
        renderCommandEncoder?.useHeap(Material.heap)
        drawGameObjects(renderCommandEncoder: renderCommandEncoder)
        drawLight(renderCommandEncoder: renderCommandEncoder)
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
    
    func createLTCTextures() {
    //    ltcMat = Skybox.loadHDR(name: "ltc_mat")
        let textureLoader = MTKTextureLoader(device: device!)
        let options_: [MTKTextureLoader.Option : Any] = [.SRGB : false]
        let url = Bundle.main.url(forResource: "ltc_mat", withExtension: "tiff")!
        ltcMat = try! textureLoader.newTexture(URL: url, options: [:])
        ltcMag = Skybox.loadHDR(name: "ltc_mag")
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
                        let mat = meshNode.material
                        var material = ShaderMaterial(baseColor: mat.baseColor, roughness: mat.roughness, metallic: mat.metallic, mipmapCount: preFilterEnvMap.mipMapCount)
                        renderCommandEncoder?.setFragmentBytes(&material, length: MemoryLayout<ShaderMaterial>.size, index: 0)
                        renderCommandEncoder?.setFragmentBytes(&lightPolygon, length: MemoryLayout<Float3>.size * 4, index: 1)
                        renderCommandEncoder?.setFragmentBuffer(mat.texturesBuffer, offset: 0, index: 15)
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
    
    func drawLight(renderCommandEncoder: MTLRenderCommandEncoder?) {
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setRenderPipelineState(light.pipelineState)
        var u = getLightUniformData()
        renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        renderCommandEncoder?.setVertexBuffer(light.vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: light.vertices.count)
    }
    
    func drawPrefilterEnvMap(renderCommandEncoder: MTLRenderCommandEncoder?, roughness: Float = 0) {
        renderCommandEncoder?.setRenderPipelineState(preFilterEnvMap.pipelineState)
        renderCommandEncoder?.setVertexBuffer(preFilterEnvMap.vertexBuffer, offset: 0, index: 0)
        var material = ShaderMaterial(baseColor: Float3(repeating: 0), roughness: roughness, metallic: 0.1, mipmapCount: preFilterEnvMap.mipMapCount)
        renderCommandEncoder?.setFragmentBytes(&material, length: MemoryLayout<ShaderMaterial>.size, index: 0)
        renderCommandEncoder?.setFragmentTexture(skybox.mipmappedTexture, index: 3)
        renderCommandEncoder?.setFragmentSamplerState(skybox.samplerState, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: preFilterEnvMap.vertices.count)
    }
    
    func drawDFGLUT(renderCommandEncoder: MTLRenderCommandEncoder?) {
        renderCommandEncoder?.setRenderPipelineState(dfgLut.pipelineState)
        renderCommandEncoder?.setVertexBuffer(dfgLut.vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: dfgLut.vertices.count)
    }
    
    func drawIrradianceMap(renderCommandEncoder: MTLRenderCommandEncoder?) {
        renderCommandEncoder?.setRenderPipelineState(irradianceMap.pipelineState)
        renderCommandEncoder?.setVertexBuffer(irradianceMap.vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.setFragmentTexture(skybox.texture, index: 3)
        renderCommandEncoder?.setFragmentSamplerState(skybox.samplerState, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: irradianceMap.vertices.count)
    }
    
    func initializeCommands() {
        let icbDescriptor = MTLIndirectCommandBufferDescriptor()
        icbDescriptor.commandTypes = [.drawIndexed]
        icbDescriptor.inheritBuffers = false
        icbDescriptor.maxVertexBufferBindCount = 25
        icbDescriptor.maxFragmentBufferBindCount = 25
        icbDescriptor.inheritPipelineState = false
        guard let indirectCB = device!.makeIndirectCommandBuffer(
            descriptor: icbDescriptor,
            maxCommandCount: gameObjects.reduce(0) {
                $0 + ($1.getComponent(Mesh.self)?.meshNodes.count ?? 0)
            },
            options: [])
            else { fatalError() }
        self.indirectCB = indirectCB
        
        for (index, gameObject) in gameObjects.enumerated() {
            if let renderPipelineStatus = gameObject.renderPipelineState, let mesh_ = gameObject.getComponent(Mesh.self) {
                let icbCommand = indirectCB.indirectRenderCommandAt(index)
                icbCommand.setRenderPipelineState(renderPipelineStatus)
                
                var u =  getUniformData(gameObject.transform.modelMatrix)
           //     icbCommand.setVertexBuffer(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
                
       //         print(mesh_.meshes.map{$0.name}, mesh_.mdlMeshes.map{$0.name})
                for (mesh, meshNodes) in mesh_.meshNodes {
                    for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                        icbCommand.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, at: bufferIndex)
                    }
                    for meshNode in meshNodes {
                        // add material through uniforms
                        let mat = meshNode.material
                        var material = ShaderMaterial(baseColor: mat.baseColor, roughness: mat.roughness, metallic: mat.metallic, mipmapCount: preFilterEnvMap.mipMapCount)
                    //    renderCommandEncoder?.setFragmentBytes(&material, length: MemoryLayout<ShaderMaterial>.size, index: 0)
                    //    renderCommandEncoder?.setFragmentBytes(&lightPolygon, length: MemoryLayout<Float3>.size * 4, index: 1)
                        icbCommand.setFragmentBuffer(mat.texturesBuffer, offset: 0, at: 15)
                        let submesh = meshNode.mesh
                        icbCommand.drawIndexedPrimitives(submesh.primitiveType,
                            indexCount: submesh.indexCount,
                            indexType: submesh.indexType,
                            indexBuffer: submesh.indexBuffer.buffer,
                            indexBufferOffset: submesh.indexBuffer.offset,
                            instanceCount: 1,
                            baseVertex: 0,
                            baseInstance: index
                        )
                    }
                }
            }
        }
    }
    
    func updateSceneData() {
        for i in 0..<lightPolygon.count {
            lightPolygon[i] = lightPolygonInitial[i] + Float3(sin(lightMovementTime) * 20, 0, 0)
        }
    }
    
    func updateGameObjects() {
        for gameObject in gameObjects {
            for behaviour in gameObject.behaviours {
                behaviour.update()
            }
        }
        if KeyboardEvents.keyStates[.incExposure] ?? false {
            exposure += 0.8 * Float(GameTimer.sharedTimer.deltaTime)
        }
        if KeyboardEvents.keyStates[.decExposure] ?? false {
            exposure -= 0.8 * Float(GameTimer.sharedTimer.deltaTime)
        }
    }
}
