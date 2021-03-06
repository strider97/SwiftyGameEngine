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
        self.vertexDescriptorMDL = Self.getMDLVertexDescriptor()
        self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(self.vertexDescriptorMDL)
    }
    private var allMeshes: [String: ([MDLMesh], [MTKMesh])] = [:]
}

extension MeshManager {
    func loadMesh(_ modelName: String, device: MTLDevice) -> ([MDLMesh], [MTKMesh]) {
        if let meshes = allMeshes[modelName] {
            return meshes
        }
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "obj") else { return ([],[]) }
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: bufferAllocator)
        asset.loadTextures()
        for sourceMesh in asset.childObjects(of: MDLMesh.self) as! [MDLMesh] {
            sourceMesh.addNormals(withAttributeNamed: Constants.smoothNormal, creaseThreshold: 0.7)
            sourceMesh.vertexDescriptor = Self.getMDLVertexDescriptor()
        }
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
    
    static func getMDLVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size*3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size*6, bufferIndex: 0)
        vertexDescriptor.attributes[3] = MDLVertexAttribute(name: Constants.smoothNormal, format: .float3, offset: MemoryLayout<Float>.size*8, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size*11)
        return vertexDescriptor
    }
    
    static func getVertexDescriptor() -> MTLVertexDescriptor {
        return MTKMetalVertexDescriptorFromModelIO(Self.getMDLVertexDescriptor())!
    }
    
}

enum Models {
    static let helmet = "helmet"
    static let legoMan = "legoMan"
    static let teapot = "teapot"
    static let planet = "planet"
}
