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
    let vertexDescriptorMDL: MDLVertexDescriptor!
    private init () {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size*3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size*6, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size*8)
        self.vertexDescriptorMDL = vertexDescriptor
        self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
    }
    private var allMeshes: [String: ([MDLMesh], [MTKMesh])] = [:]
}

extension MeshManager {
    func loadMesh(_ modelName: String, device: MTLDevice) -> ([MDLMesh], [MTKMesh]) {
        if let meshes = allMeshes[modelName] {
            return meshes
        }
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "usd") else { return ([],[]) }
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: self.vertexDescriptorMDL, bufferAllocator: bufferAllocator)
        var meshes: [MTKMesh]
        var meshesMDL: [MDLMesh]
        do {
            try (meshesMDL, meshes) = MTKMesh.newMeshes(asset: asset, device: device)
            allMeshes[modelName] = (meshesMDL, meshes)
        } catch let error as NSError {
            fatalError(error.description)
        }
        return (meshesMDL, meshes)
    }
}

enum Models {
    static let helmet = "helmet"
    static let legoMan = "legoMan"
    static let teapot = "teapot"
    static let planet = "planet"
}
