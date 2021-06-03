//
//  Utils.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import Foundation
import MetalKit

typealias Quat = simd_quatf
typealias Matrix3 = simd_float3x3

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

    init() {}
}

extension Transform {
    func translate(_ position: Float3) {
        modelMatrix[3] = Float4(position, modelMatrix[3][3])
    }

    func scale(_ scale: Float3) {
        modelMatrix = modelMatrix * Matrix4(diagonal: Float4(scale, 1))
    }

    func rotate(angle: Float, axis: Float3) {
        rotation = Quat(angle: angle, axis: axis)
        modelMatrix *= Matrix4(rotation)
    }
}

class Component: NSObject {
    weak var gameObject: GameObject!
    override init() {}
    init(gameObject: GameObject) {
        self.gameObject = gameObject
    }
}

enum KeyboardEvents: String, CaseIterable {
    case forward = "w"
    case backward = "s"
    case left = "a"
    case right = "d"
    case down = "k"
    case up = "i"
    case incExposure = "o"
    case decExposure = "l"
    case none = ""

    static var keyStates: [KeyboardEvents: Bool] = [:]

    static func getEventForKey(_ key: String) -> KeyboardEvents {
        return KeyboardEvents.allCases.filter {
            $0.rawValue == key
        }.first ?? .none
    }

    static func pressDown(_ key: String) {
        let event = getEventForKey(key.lowercased())
        keyStates[event] = true
    }

    static func pressUp(_ key: String) {
        let event = getEventForKey(key.lowercased())
        keyStates[event] = false
    }
}

extension Float4 {
    var xyz: Float3 {
        return Float3(x, y, z)
    }
}

extension Matrix4 {
    init(scaleBy s: Float) {
        self.init(Float4(s, 0, 0, 0),
                  Float4(0, s, 0, 0),
                  Float4(0, 0, s, 0),
                  Float4(0, 0, 0, 1))
    }

    init(rotationAbout axis: Float3, by angleRadians: Float) {
        let a = normalize(axis)
        let x = a.x, y = a.y, z = a.z
        let c = cosf(angleRadians)
        let s = sinf(angleRadians)
        let t = 1 - c
        self.init(Float4(t * x * x + c, t * x * y + z * s, t * x * z - y * s, 0),
                  Float4(t * x * y - z * s, t * y * y + c, t * y * z + x * s, 0),
                  Float4(t * x * z + y * s, t * y * z - x * s, t * z * z + c, 0),
                  Float4(0, 0, 0, 1))
    }

    init(translationBy t: Float3) {
        self.init(Float4(1, 0, 0, 0),
                  Float4(0, 1, 0, 0),
                  Float4(0, 0, 1, 0),
                  Float4(t[0], t[1], t[2], 1))
    }

    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = lhs ? far / (far - near) : far / (near - far)
        let X = Float4(x, 0, 0, 0)
        let Y = Float4(0, y, 0, 0)
        let Z = lhs ? Float4(0, 0, z, 1) : Float4(0, 0, z, -1)
        let W = lhs ? Float4(0, 0, z * -near, 0) : Float4(0, 0, z * near, 0)
        self.init()
        columns = (X, Y, Z, W)
    }

    init(orthoLeft left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        let X = Float4(2 / (right - left), 0, 0, 0)
        let Y = Float4(0, 2 / (top - bottom), 0, 0)
        let Z = Float4(0, 0, 1 / (far - near), 0)
        let W = Float4((left + right) / (left - right),
                       (top + bottom) / (bottom - top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }

    var normalMatrix: Matrix3 {
        let upperLeft = Matrix3(self[0].xyz, self[1].xyz, self[2].xyz)
        return upperLeft.transpose.inverse
    }
}
