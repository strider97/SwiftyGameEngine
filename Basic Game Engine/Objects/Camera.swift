//
//  Camera.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

class Camera {
    var position = Float3(0, 0, 5) {
        didSet {
            updateLookatMatrix()
        }
    }
    var target = Float3 (0, 0, 0) {
        didSet {
            updateLookatMatrix()
        }
    }
    lazy var lookAtMatrix: Matrix4 = Matrix4.viewMatrix(position: position, target: target, up: Camera.WorldUp)
    
    init(position: Float3, target: Float3) {
        self.position = position
        self.target = target
    }
    
    init() {}
    
    private func updateLookatMatrix() {
        lookAtMatrix = Matrix4.viewMatrix(position: position, target: target, up: Camera.WorldUp)
    }
}

extension Camera {
    var direction: Float3 {
        return (position - target).normalized
    }
    var front: Float3 {
        return -direction
    }
    var right: Float3 {
        return Camera.WorldUp.cross(direction)
    }
    var up: Float3 {
        return direction.cross(right)
    }
}

extension Camera {
    static let WorldUp = Float3(0, 1, 0)
}
