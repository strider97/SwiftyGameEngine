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
    init() {
        currentScene = SimpleScene()
    }

    func loadScene(scene: Scene) {
        currentScene = scene
    }
}

class Scene: NSObject {
    var name = "Game Scene"
    var gameObjects: [GameObject] = []
    var rayTracer: Raytracer?
    static let W: Float = 1280
    static let H: Float = 720
    final let P = Matrix4(projectionFov: MathConstants.PI.rawValue / 3, near: 0.01, far: 500, aspect: Scene.W / Scene.H)
    var sunDirection = Float3(8, 8, 1)
    var orthoGraphicP = Matrix4(orthoLeft: -10, right: 10, bottom: -10, top: 10, near: 0.01, far: 100)
    lazy var shadowViewMatrix = Matrix4.viewMatrix(position: sunDirection, target: Float3(0, 0, 0), up: Camera.WorldUp)
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
    var gBufferData = GBufferData(size: CGSize(width: 256, height: 256))
    var lightPolygon: [Float3] = [
        Float3(-6, -1.9, 20),
        Float3(0, 3, 20),
        Float3(6, -1.9, 20),
        Float3(0, 10, 20),
    ]

    var lightPolygonInitial: [Float3] = [
        Float3(-6, -1.9, 20),
        Float3(0, 3, 20),
        Float3(6, -1.9, 20),
        Float3(0, 10, 20),
    ]

    var light: PolygonLight
    var sphere = GameObject(modelName: "sphere")

    override init() {
        light = PolygonLight(vertices: lightPolygon)
        super.init()
        camera = getCamera()
        skybox = getSkybox()
        timer.startTime = Float(CACurrentMediaTime())
        depthStencilState = buildDepthStencilState(device: device!)
        gameObjects = getGameObjects()
        addPhysics()
        addBehaviour()
        createShadowTexture()
        createLTCTextures()
        sphere.transform.scale(Float3(repeating: 0.2))
        sphere.renderPipelineState = Descriptor.createLightProbePipelineState()
    }

    func getGameObjects() -> [GameObject] { [] }
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
    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {
        if rayTracer == nil {
            rayTracer = Raytracer(metalView: view)
            rayTracer?.camera = camera
            rayTracer?.scene = self
        }
        //     rayTracer?.mtkView(view, drawableSizeWillChange: CGSize(width: Constants.probeReso * Constants.probeCount, height: Constants.probeReso * Constants.probeCount))
        rayTracer?.mtkView(view, drawableSizeWillChange: CGSize(width: Constants.probeCount * Constants.probeReso, height: Constants.probeReso))
    }

    func draw(in view: MTKView) {
        timer.updateTime()
        camera.moveCam()
        let p = view.window!.mouseLocationOutsideOfEventStream
        let mouse = Float2(Float(p.x), Float(p.y))
        if mouse.x < Self.W, mouse.y < Self.H, mouse.x > 0.0, mouse.y > 0.0 {
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
        M[3][0] = Float(sin(GameTimer.sharedTimer.time) * 20)
        return Uniforms(M: M, V: camera.lookAtMatrix, P: P, eye: camera.position, exposure: exposure)
    }

    func getLightProbeUniformData(_ index: Int) -> Uniforms {
        var M = sphere.transform.modelMatrix
        let pos = rayTracer!.irradianceField.probeLocationsArray[index]
        M[3][0] = pos[0]
        M[3][1] = pos[1]
        M[3][2] = pos[2]
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
        return Uniforms(M: M, V: shadowViewMatrix, P: orthoGraphicP, eye: camera.position)
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

            for i in 0 ..< preFilterEnvMap.mipMapCount {
                let mipmapEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: preFilterEnvMap.renderPassDescriptors[i])
                drawPrefilterEnvMap(renderCommandEncoder: mipmapEncoder, roughness: Float(i) / Float(preFilterEnvMap.mipMapCount))
                mipmapEncoder?.endEncoding()
            }

            let blitCopyEncoder = commandBuffer?.makeBlitCommandEncoder()
            blitCopyEncoder?.generateMipmaps(for: preFilterEnvMap.texture)
            for i in 0 ..< preFilterEnvMap.mipMapCount {
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

        rayTracer?.draw(in: view, commandBuffer: commandBuffer)
        rayTracer?.drawAccumulation(in: view, commandBuffer: commandBuffer)
        let shadowCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: shadowDescriptor)
        shadowCommandEncoder?.setDepthStencilState(depthStencilState)
        shadowCommandEncoder?.setCullMode(.front)
        //    shadowCommandEncoder?.setDepthBias(0.001, slopeScale: 1.0, clamp: 0.01)
        drawGameObjects(renderCommandEncoder: shadowCommandEncoder, renderPassType: .shadow)
        shadowCommandEncoder?.endEncoding()

//        let gBufferCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: gBufferData.gBufferRenderPassDescriptor)
//        gBufferCommandEncoder?.setDepthStencilState(depthStencilState)
//        drawGameObjects(renderCommandEncoder: gBufferCommandEncoder, renderPassType: .gBuffer)
//        gBufferCommandEncoder?.endEncoding()

        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setFragmentTexture(preFilterEnvMap.texture, index: TextureIndex.preFilterEnvMap.rawValue)
        renderCommandEncoder?.setFragmentTexture(dfgLut.texture, index: TextureIndex.DFGlut.rawValue)
        renderCommandEncoder?.setFragmentTexture(irradianceMap.texture, index: TextureIndex.irradianceMap.rawValue)
        renderCommandEncoder?.setFragmentTexture(ltcMat, index: TextureIndex.ltc_mat.rawValue)
        renderCommandEncoder?.setFragmentTexture(ltcMag, index: TextureIndex.ltc_mag.rawValue)
        renderCommandEncoder?.setFragmentTexture(shadowTexture, index: TextureIndex.shadowMap.rawValue)
        renderCommandEncoder?.setFragmentTexture(gBufferData.worldPos, index: TextureIndex.worldPos.rawValue)
        renderCommandEncoder?.setFragmentTexture(gBufferData.normal, index: TextureIndex.normal.rawValue)
        renderCommandEncoder?.setFragmentTexture(gBufferData.flux, index: TextureIndex.flux.rawValue)
        renderCommandEncoder?.setFragmentTexture(rayTracer?.irradianceField.ambientCubeTextureFinalR, index: TextureIndex.textureDDGIR.rawValue)
        renderCommandEncoder?.setFragmentTexture(rayTracer?.irradianceField.ambientCubeTextureFinalG, index: TextureIndex.textureDDGIG.rawValue)
        renderCommandEncoder?.setFragmentTexture(rayTracer?.irradianceField.ambientCubeTextureFinalB, index: TextureIndex.textureDDGIB.rawValue)
        renderCommandEncoder?.setCullMode(.front)
        drawGameObjects(renderCommandEncoder: renderCommandEncoder)
    //    drawLightProbes(renderCommandEncoder: renderCommandEncoder)
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
        shadowTexture = Descriptor.build2DTexture(pixelFormat: .depth32Float, size: CGSize(width: 2 * Int(Self.W), height: 2 * Int(Self.W)))
        shadowDescriptor.setupDepthAttachment(texture: shadowTexture)
        shadowPipelineState = Descriptor.createShadowPipelineState()
    }

    func createLTCTextures() {
        //    ltcMat = Skybox.loadHDR(name: "ltc_mat")
        let textureLoader = MTKTextureLoader(device: device!)
        let options_: [MTKTextureLoader.Option: Any] = [.SRGB: false]
        let url = Bundle.main.url(forResource: "ltc_mat", withExtension: "tiff")!
        ltcMat = try! textureLoader.newTexture(URL: url, options: [:])
        ltcMag = Skybox.loadHDR(name: "ltc_mag")
    }

    func drawGameObjects(renderCommandEncoder: MTLRenderCommandEncoder?, renderPassType: RenderPassType = .shading) {
        for (i, gameObject) in gameObjects.enumerated() {
            if let renderPipelineStatus = renderPassType == .shadow ? shadowPipelineState : (renderPassType == .shading ? gameObject.renderPipelineState : gBufferData.renderPipelineState), let mesh_ = gameObject.getComponent(Mesh.self) {
                renderCommandEncoder?.setRenderPipelineState(renderPipelineStatus)

                var u = renderPassType == .shading ? getUniformData(gameObject.transform.modelMatrix) : getFarShadowUniformData(gameObject.transform.modelMatrix)
                if renderPassType == .shading || renderPassType == .gBuffer {
                    var s = ShadowUniforms(P: orthoGraphicP, V: shadowViewMatrix, sunDirection: sunDirection.normalized)
                    renderCommandEncoder?.setVertexBytes(&s, length: MemoryLayout<ShadowUniforms>.stride, index: 2)
                    let irradianceField = rayTracer!.irradianceField!
                    var lightProbeData = LightProbeData(gridEdge: irradianceField.gridEdge, gridOrigin: irradianceField.origin, probeGridWidth: irradianceField.width, probeGridHeight: irradianceField.height, probeGridCount: Int3(Constants.probeGrid.0, Constants.probeGrid.1, Constants.probeGrid.2))
                    renderCommandEncoder?.setFragmentBytes(&lightProbeData, length: MemoryLayout<LightProbeData>.stride, index: 2)
                }
                renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)

                //         print(mesh_.meshes.map{$0.name}, mesh_.mdlMeshes.map{$0.name})
                for (mesh, meshNodes) in mesh_.meshNodes {
                    for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                        renderCommandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex)
                    }
                    for meshNode in meshNodes {
                        // add material through uniforms
                        if renderPassType != .shadow {
                            let mat = meshNode.material
                            var material = ShaderMaterial(baseColor: mat.baseColor, roughness: mat.roughness, metallic: mat.metallic, mipmapCount: preFilterEnvMap.mipMapCount)
                            renderCommandEncoder?.setFragmentBytes(&material, length: MemoryLayout<ShaderMaterial>.size, index: 0)
                            renderCommandEncoder?.setFragmentBytes(&lightPolygon, length: MemoryLayout<Float3>.size * 4, index: 1)
                            renderCommandEncoder?.setFragmentTexture(mat.textureSet.baseColor, index: TextureIndex.baseColor.rawValue)
                            if i == 1 {
                                renderCommandEncoder?.setFragmentTexture(rayTracer?.renderTarget!, index: TextureIndex.baseColor.rawValue)
                            }
                            if renderPassType == .shading {
                                renderCommandEncoder?.setFragmentTexture(mat.textureSet.roughness, index: TextureIndex.roughness.rawValue)
                                renderCommandEncoder?.setFragmentTexture(mat.textureSet.metallic, index: TextureIndex.metallic.rawValue)
                                renderCommandEncoder?.setFragmentTexture(mat.textureSet.normalMap, index: TextureIndex.normalMap.rawValue)
                                renderCommandEncoder?.setFragmentTexture(mat.textureSet.ao, index: TextureIndex.ao.rawValue)
                            }
                        }
                        let submesh = meshNode.mesh
                        renderCommandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
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

    func drawLightProbes(renderCommandEncoder: MTLRenderCommandEncoder?) {
        guard let mesh_ = sphere.getComponent(Mesh.self) else { return }
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setRenderPipelineState(sphere.renderPipelineState!)
        let irradianceField = rayTracer!.irradianceField!
        var lightProbeData = LightProbeData(gridEdge: irradianceField.gridEdge, gridOrigin: irradianceField.origin, probeGridWidth: irradianceField.width, probeGridHeight: irradianceField.height, probeGridCount: Int3(0, 0, 0))
        renderCommandEncoder?.setFragmentBytes(&lightProbeData, length: MemoryLayout<LightProbeData>.stride, index: 0)
        renderCommandEncoder?.setFragmentTexture(irradianceField.ambientCubeTextureFinalR, index: 0)
        for (index, _) in rayTracer!.irradianceField.probeLocationsArray.enumerated() {
            var u = getLightProbeUniformData(index)
            renderCommandEncoder?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
            for (mesh, meshNodes) in mesh_.meshNodes {
                for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                    renderCommandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex)
                }
                for meshNode in meshNodes {
                    let submesh = meshNode.mesh
                    renderCommandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
                }
            }
        }
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

    func updateSceneData() {
        //    for i in 0..<lightPolygon.count {
        //        lightPolygon[i] = lightPolygonInitial[i] + Float3(sin(GameTimer.sharedTimer.time) * 20, 0, 0)
        //    }
        sunDirection.x = abs(40 * cos(GameTimer.sharedTimer.time / 3)) - 2
        shadowViewMatrix = Matrix4.viewMatrix(position: sunDirection, target: Float3(0, 0, 0), up: Camera.WorldUp)
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

struct ShadowUniforms {
    var P: Matrix4
    var V: Matrix4
    var sunDirection: Float3
}

enum RenderPassType {
    case shadow
    case gBuffer
    case shading
}
