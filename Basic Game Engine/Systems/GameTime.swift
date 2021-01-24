//
//  GameTime.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class GameTimer {
    static let sharedTimer = GameTimer()
    var time = 0.0
    var deltaTime = 0.0
    var startTime = 0.0
    private init() {}
    
    func updateTime() {
        deltaTime = CACurrentMediaTime() - startTime - time
        time += deltaTime
    //    print("FPS: \(1/deltaTime)")
    }
}
