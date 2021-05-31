//
//  IrradianceField.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/05/21.
//

import Foundation
import MetalKit

struct LightProbeData {
    let gridEdge: Float3
    let gridOrigin: Float3
    let probeGridWidth: Int
    let probeGridHeight: Int
}

class IrradianceField {
    let width: Int
    let height: Int
    let depth: Int
    var ambientCubeTexture: MTLTexture!
    var probeLocations: MTLBuffer!
    var probeCount: Int
    var probeLocationsArray: [Float3] = []
    let origin: Float3
    let gridEdge: Float3
    
    convenience init(_ w: Int, _ centre: Float3, _ gridSize: Float3) {
        self.init(w, w, w, centre, gridSize)
    }
    
    init(_ w: Int, _ h: Int, _ d: Int, _ centre: Float3, _ gridSize: Float3) {
        width = w
        height = h
        depth = d
        probeCount = w * h * d
        ambientCubeTexture = Descriptor.build3DTexture(dimW: w*h, dimH: d, dimD: 2, label: "Irradiance Field", pixelFormat: .rgba32Float)
        gridEdge = gridSize / Float3(Float(w-1), Float(h-1), Float(d-1))
        origin = centre - gridSize/2
        makeBuffer(origin, gridEdge)
    }
    
    // fill (0, 0, 0) -> (w, 0, 0) -> (w, h, 0) -> (w, h, d)
    func indexToGridPos(_ index: Int, _ origin: Float3, _ gridEdge: Float3) -> Float3{
        let indexD = index / (width * height)
        let indexH = (index % (width * height)) / width
        let indexW = (index % (width * height)) % width
        return origin + Float3(Float(indexW), Float(indexH), Float(indexD)) * gridEdge
    }
    
    func makeBuffer(_ origin: Float3, _ gridEdge: Float3) {
        let device = Device.sharedDevice.device!
        for i in 0..<probeCount {
            let pos = indexToGridPos(i, origin, gridEdge)
            probeLocationsArray.append(pos)
        }
        print(probeLocationsArray)
        self.probeLocations = device.makeBuffer(bytes: probeLocationsArray, length: MemoryLayout<Float3>.stride * probeCount, options: .storageModeManaged)!
    }
}
