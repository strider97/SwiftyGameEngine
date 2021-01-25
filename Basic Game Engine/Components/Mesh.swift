//
//  Mesh.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit
import ModelIO

class Mesh: Component {
    var vertices: [Vertex] = []
    var vertexBuffer: MTLBuffer?
    var vertexDescriptor: MTLVertexDescriptor!
    var meshes: [MTKMesh] = []
    
    init(modelName: String) {
        super.init()
        self.vertexDescriptor = MeshManager.meshManager.vertexDescriptor
        loadModel(modelName, device: Device.sharedDevice.device!)
    }
}

extension Mesh {
    func loadModel(_ modelName: String, device: MTLDevice) {
        meshes = MeshManager.meshManager.loadMesh(modelName, device: device)
    }
}


