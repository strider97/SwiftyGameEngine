//
//  GameObject.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

typealias Matrix4 = simd_float4x4

class GameObject {
    var name: String = ""
    var transform = Transform()
    var components: [String:Component] = [:]
    var renderPipelineState: MTLRenderPipelineState?
    var behaviours: [Behaviour] = []
    
    init (_ position: Float3) {
        self.transform = Transform(position)
    }
    init () {}
    init (modelName: String) {
        name = modelName
        let mesh = Mesh(modelName: modelName)
        addComponent(mesh)
        createRenderPipelineState(material: Material(), vertexDescriptor: mesh.vertexDescriptor)
    }
}

extension GameObject {
    func addComponent<T: Component> (_ component: T) {
        components[String(describing: T.self)] = component
    }
    
    func addBehaviour(_ behaviour: Behaviour) {
        behaviours.append(behaviour)
    }
    
    func getComponent<T: Component> (_ type: T.Type) -> T?{
        return components[String(describing: T.self)] as? T
    }
    
    func createRenderPipelineState(material: Material, vertexDescriptor: MTLVertexDescriptor) {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = Constants.pixelFormat
        renderPipelineDescriptor.vertexFunction = material.vertexShaderFunction
        renderPipelineDescriptor.fragmentFunction = material.fragmentShaderFunction
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            try renderPipelineState = Device.sharedDevice.device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch let error as NSError {
            print(error)
        }
    }
    
    
}
