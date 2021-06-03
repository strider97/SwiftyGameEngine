//
//  GameTime.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

typealias Float2 = simd_float2
class GameTimer {
    static let sharedTimer = GameTimer()
    var time: Float = 0.0
    var deltaTime: Float = 0.0
    var startTime: Float = 0.0
    private init() {}

    func updateTime() {
        deltaTime = max(Float(CACurrentMediaTime()) - startTime - time, 1.0 / 60)
        time += deltaTime
        //    print("FPS: \(1/deltaTime)")
    }
}

class Input {
    static let sharedInput = Input()
    var mousePosition: Float2 = Float2(0, 0)
    var deltaMouse: Float2 = Float2(0, 0)
    var firstMouseInteraction = true
    var mouseClicked = false
    private init() {}

    func updateMousePosition(pos: Float2) {
        if !firstMouseInteraction {
            deltaMouse = pos - mousePosition
        } else {
            firstMouseInteraction = false
        }
        mousePosition = pos
    }

    func updateMouseClicked(clicked: Bool) {
        mouseClicked = clicked
    }
}
