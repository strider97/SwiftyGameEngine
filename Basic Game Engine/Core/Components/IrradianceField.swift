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
    let probeGridCount: Int3
}

class IrradianceField {
    let width: Int
    let height: Int
    let depth: Int
    var ambientCubeTextureR: MTLTexture!
    var ambientCubeTextureG: MTLTexture!
    var ambientCubeTextureB: MTLTexture!
    var ambientCubeTextureFinalR: MTLTexture!
    var ambientCubeTextureFinalG: MTLTexture!
    var ambientCubeTextureFinalB: MTLTexture!
    var probeLocations: MTLBuffer!
    var probeDirections: MTLBuffer!
    var probeCount: Int
    var probeLocationsArray: [Float3] = []
    var probeDirectionsArray: [Float3] = []
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
        ambientCubeTextureR = Descriptor.build3DTexture(dimW: w * h, dimH: d, dimD: Constants.probeReso * Constants.probeReso, label: "Irradiance Field", pixelFormat: .rgba32Float)
        ambientCubeTextureFinalR = Descriptor.build3DTexture(dimW: w * h, dimH: d, dimD: 2, label: "Irradiance Field final", pixelFormat: .rgba32Float)
        
        ambientCubeTextureG = Descriptor.build3DTexture(dimW: w * h, dimH: d, dimD: Constants.probeReso * Constants.probeReso, label: "Irradiance Field", pixelFormat: .rgba32Float)
        ambientCubeTextureFinalG = Descriptor.build3DTexture(dimW: w * h, dimH: d, dimD: 2, label: "Irradiance Field final", pixelFormat: .rgba32Float)
        
        ambientCubeTextureB = Descriptor.build3DTexture(dimW: w * h, dimH: d, dimD: Constants.probeReso * Constants.probeReso, label: "Irradiance Field", pixelFormat: .rgba32Float)
        ambientCubeTextureFinalB = Descriptor.build3DTexture(dimW: w * h, dimH: d, dimD: 2, label: "Irradiance Field final", pixelFormat: .rgba32Float)
        gridEdge = gridSize / Float3(Float(w - 1), Float(h - 1), Float(d - 1))
        origin = centre - gridSize / 2
        makeBuffer(origin, gridEdge)
    }

    // fill (0, 0, 0) -> (w, 0, 0) -> (w, h, 0) -> (w, h, d)
    func indexToGridPos(_ index: Int, _ origin: Float3, _ gridEdge: Float3) -> Float3 {
        let indexD = index / (width * height)
        let indexH = (index % (width * height)) / width
        let indexW = (index % (width * height)) % width
        return origin + Float3(Float(indexW), Float(indexH), Float(indexD)) * gridEdge
    }

    static func sphericalFibonacci9(_ i_: Float, _ n: Float) -> Float3 {
        let i = i_ + 0.5
        let goldenRatio: Float = 1.6180339
        let theta = 2 * MathConstants.PI.rawValue * i / goldenRatio
        let phi = acos(1 - 2 * (i + 0.5) / n)
        return Float3(cos(theta) * sin(phi), sin(theta) * sin(phi), cos(phi))
    }
    
    static func getRandomDirection() -> Float3 {
        let theta = 2.0 * Double(MathConstants.PI.rawValue) * Double.random(in: 0...1);
        // corrrect
        let phi = acos(2*Double.random(in: 0...1)-1.0);
        // incorrect
        //phi = PI*irand(0,1);
        return Float3 (
            Float(cos(theta)*sin(phi)),
            Float(sin(theta)*sin(phi)),
            Float(cos(phi))
        )
    }

    func indexToTexPos_(index: Int) -> Float2 {
        let indexD = index / (width * height)
        let indexH = (index % (width * height))
        return Float2(Float(indexH), Float(indexD))
    }

    func gridPosToTex(pos: Float3) -> Int {
        let texPos = Float3((pos - origin) / gridEdge)
        var index = Int(rint(texPos.z)) * width * height
        index += Int(rint(texPos.y)) * width + Int(rint(texPos.x))
        return index
        //    return indexToTexPos_(index, width, height)
    }

    func gridPosToTex_(pos: Float3) -> Float2 {
        let texPos = (pos - origin) / gridEdge
        //    return ushort2(0, 0);
        return Float2(texPos.y * Float(width) + texPos.x, texPos.z)
    }

    func makeBuffer(_ origin: Float3, _ gridEdge: Float3) {
        let device = Device.sharedDevice.device!
        for i in 0 ..< probeCount {
            let pos = indexToGridPos(i, origin, gridEdge)
            probeLocationsArray.append(pos)
        }
        print(probeLocationsArray)
        probeLocations = device.makeBuffer(bytes: probeLocationsArray, length: MemoryLayout<Float3>.stride * probeCount, options: .storageModeManaged)!
        let numRays = Constants.probeReso * Constants.probeReso * 1000
        for _ in 0 ..< numRays {
        //    let dir = Self.sphericalFibonacci9(Float(i), Float(numRays))
            let dir = Self.getRandomDirection()
            probeDirectionsArray.append(dir)
        }
        //    print(probeDirectionsArray)
        probeDirections = device.makeBuffer(bytes: probeDirectionsArray, length: MemoryLayout<Float3>.stride * numRays, options: .storageModeManaged)!
        print(self.origin)
        for val in probeLocationsArray {
            let i = gridPosToTex(pos: val)
            print(i, indexToTexPos_(index: i), gridPosToTex_(pos: val))
        }
    }
}
