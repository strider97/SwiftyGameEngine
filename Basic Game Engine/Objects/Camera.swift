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
    var direction = Float3(0, 0, 1) {
        didSet {
            updateLookatMatrix()
        }
    }
    
    lazy var lookAtMatrix: Matrix4 = Matrix4.viewMatrix(position: position, target: position + front, up: Camera.WorldUp)
    
    init(position: Float3, target: Float3) {
        self.position = position
        self.direction = (position - target).normalized
        registerKeyboardEvents()
    }
    
    init() {
        registerKeyboardEvents()
    }
    
    private func updateLookatMatrix() {
        lookAtMatrix = Matrix4.viewMatrix(position: position, target: position + front, up: Camera.WorldUp)
    }
    
    var speed: Float = 0.2
}

extension Camera {
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

extension Camera {
    func registerKeyboardEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyIsPressed(_:)), name: NSNotification.Name.keyIsPressed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyReleased(_:)), name: NSNotification.Name.keyReleased, object: nil)
    }
    
    @objc func keyIsPressed(_ notification: Notification) {
        let _ = (notification.object as? String) ?? ""
    //    translateCam(key: key)
    }
    @objc func keyReleased(_ notification: Notification) {
        let _ = (notification.object as? String) ?? ""
    //    translateCam(key: key)
    }
}

extension Camera {
    func moveCam() {
        for keyState in KeyboardEvents.allCases {
            if KeyboardEvents.keyStates[keyState] ?? false {
                translateCam(key: keyState)
            }
        }
    }
    
    private func translateCam(key: KeyboardEvents) {
        switch key {
        case KeyboardEvents.forward:
            position += front * speed
        case KeyboardEvents.backward:
            position -= front * speed
        case KeyboardEvents.right:
            position += right * speed
        case KeyboardEvents.left:
            position -= right * speed
        default:
            return
        }
    }
}

extension NSNotification.Name {
    static let keyIsPressed = NSNotification.Name("keyIsPressed")
    static var keyReleased = NSNotification.Name("keyReleased")
}
