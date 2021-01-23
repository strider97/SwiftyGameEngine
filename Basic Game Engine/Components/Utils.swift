//
//  Utils.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit
import Foundation

typealias Quat = simd_quatf

class Transform {
    var modelMatrix: Matrix4 = Matrix4(1)
    var position: Float3 {
        get {
            return Float3(modelMatrix[3].x, modelMatrix[3].y, modelMatrix[3].z)
        }
        set(newPosition) {
            translate(newPosition)
        }
    }
    var rotation: Quat = Quat(vector: Float4(0, 0, 0, 1))
    
    init(_ position: Float3) {
        self.position = position
    }
    init () {}
}

extension Transform {
    func translate(_ position: Float3) {
        modelMatrix[3] = Float4(position, modelMatrix[3][3])
    }
}

class Component: NSObject {
    weak var gameObject: GameObject!
}

class Behaviour: Component {
    func start() {}
    func update() {}
}
