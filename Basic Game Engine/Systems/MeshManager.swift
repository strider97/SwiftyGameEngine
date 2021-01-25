//
//  ModelLoader.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 25/01/21.
//

import MetalKit
import ModelIO

class MeshManager {
    static let meshManager = MeshManager()
    let vertexDescriptor: MTLVertexDescriptor!
    private init () {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size*3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size*6, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size*8)
        self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
    }
    private var allMeshes: [String: [MTKMesh]] = [:]
}

extension MeshManager {
    func loadMesh(_ modelName: String, device: MTLDevice) -> [MTKMesh] {
        if let meshes = allMeshes[modelName] {
            return meshes
        }
        let url = Bundle.main.url(forResource: modelName, withExtension: "obj")
        let vertexDescriptor = MDLVertexDescriptor()
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        var meshes: [MTKMesh]
        do {
            try (_, meshes) = MTKMesh.newMeshes(asset: asset, device: device)
            allMeshes[modelName] = meshes
        } catch let error as NSError {
            fatalError(error.description)
        }
        return meshes
    }
}

enum Models {
    static let helmet = "helmet"
    static let legoMan = "legoMan"
    static let teapot = "teapot2"
    static let planet = "planet"
}
