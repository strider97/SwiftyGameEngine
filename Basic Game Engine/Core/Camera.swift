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

    var yaw = MathConstants.PI.rawValue / 2
    var pitch: Float = 0

    lazy var lookAtMatrix: Matrix4 = Matrix4.viewMatrix(position: position, target: position + front, up: Camera.WorldUp)

    convenience init(position: Float3, target: Float3) {
        self.init()
        self.position = position
        direction = (position - target).normalized
        registerKeyboardEvents()
    }

    init() {
        registerKeyboardEvents()
    }

    private func updateLookatMatrix() {
        lookAtMatrix = Matrix4.viewMatrix(position: position, target: position + front, up: Camera.WorldUp)
    }

    var speed: Float = 4
    var mouseSpeed: Float = 0.2
    private var deltaMouse = Float2(0, 0)
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
        NotificationCenter.default.addObserver(self, selector: #selector(mouseMoved(_:)), name: NSNotification.Name.mouseMoved, object: nil)
    }

    @objc func keyIsPressed(_ notification: Notification) {
        _ = (notification.object as? String) ?? ""
        //    translateCam(key: key)
    }

    @objc func keyReleased(_ notification: Notification) {
        _ = (notification.object as? String) ?? ""
        //    translateCam(key: key)
    }

    @objc func mouseMoved(_: Notification) {
        rotateCam()
    }
}

extension Camera {
    func moveCam() {
        for keyState in KeyboardEvents.allCases {
            if KeyboardEvents.keyStates[keyState] ?? false {
                translateCam(key: keyState)
            }
        }
        //    rotateCam()
    }

    func rotateCam() {
        yaw += mouseSpeed * GameTimer.sharedTimer.deltaTime *
            Input.sharedInput.deltaMouse.x
        pitch -= mouseSpeed * GameTimer.sharedTimer.deltaTime *
            Input.sharedInput.deltaMouse.y
        pitch = max(-MathConstants.PI.rawValue / 2 + 1.15, min(MathConstants.PI.rawValue / 2 - 1.15, pitch))
        direction = Float3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)).normalized
    }

    private func translateCam(key: KeyboardEvents) {
        switch key {
        case .forward:
            position += front * speed * GameTimer.sharedTimer.deltaTime
        case .backward:
            position -= front * speed * GameTimer.sharedTimer.deltaTime
        case .right:
            position += right * speed * GameTimer.sharedTimer.deltaTime
        case .left:
            position -= right * speed * GameTimer.sharedTimer.deltaTime
        case .up:
            position += Camera.WorldUp * speed * GameTimer.sharedTimer.deltaTime * 0.6
        case .down:
            position -= Camera.WorldUp * speed * GameTimer.sharedTimer.deltaTime * 0.6
        default:
            return
        }
    }
}

extension NSNotification.Name {
    static let keyIsPressed = NSNotification.Name("keyIsPressed")
    static let keyReleased = NSNotification.Name("keyReleased")
    static let mouseMoved = NSNotification.Name("mouseMoved")
}
