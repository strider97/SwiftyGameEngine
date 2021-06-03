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
    private var meshes: [MTKMesh] = []
    private var mdlMeshes: [MDLMesh] = []
    var meshNodes: [(MTKMesh, [MeshNode])] = []

    init(modelName: String) {
        super.init()
        vertexDescriptor = MeshManager.meshManager.vertexDescriptor
        loadModel(modelName, device: Device.sharedDevice.device!)
    }
}

extension Mesh {
    func loadModel(_ modelName: String, device: MTLDevice) {
        mdlMeshes = MeshManager.meshManager.loadMesh(modelName, device: device).0
        meshes = MeshManager.meshManager.loadMesh(modelName, device: device).1
        assert(mdlMeshes.count == meshes.count)
        let textureLoader = MTKTextureLoader(device: device)
        for i in 0 ..< meshes.count {
            var meshNodeArray: [MeshNode] = []
            let mdlSubmeshes = mdlMeshes[i].submeshes as! [MDLSubmesh]
            for (index, submesh) in meshes[i].submeshes.enumerated() {
                let meshNode = MeshNode(submesh: submesh, material: mdlSubmeshes[index].material, textureLoader: textureLoader)
                meshNodeArray.append(meshNode)
            }
            meshNodes.append((meshes[i], meshNodeArray))
        }
    }
}

class MeshNode {
    var material: Material
    var mesh: MTKSubmesh
    var modelMatrix: Matrix4

    init(submesh: MTKSubmesh, material: MDLMaterial?, textureLoader: MTKTextureLoader) {
        mesh = submesh
        self.material = Material(material, textureLoader)
        modelMatrix = Matrix4(1)
    }
}
