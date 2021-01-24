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

enum KeyboardEvents: String, CaseIterable {
    case forward = "w"
    case backward = "s"
    case left = "a"
    case right = "d"
    case none = ""
    
    static var keyStates: [KeyboardEvents: Bool] = [:]
    
    static func getEventForKey(_ key: String) -> KeyboardEvents{
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
