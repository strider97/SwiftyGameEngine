//
//  Behaviour.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/01/21.
//

import Foundation

class Behaviour: Component {
    override init(gameObject: GameObject) {
        super.init(gameObject: gameObject)
        start()
        gameObject.addBehaviour(self)
    }
    func start() {}
    func update() {}
}

class Move: Behaviour {
    var speed: Float = 0
    var dir = Float3(1, 0, 0)
    let wall: Float = 5.0
    init(gameObject: GameObject, speed: Float) {
        super.init(gameObject: gameObject)
        self.speed = speed
    }
    override func start() {
        speed = 1
    //    print(SceneManager.sharedManager.currentScene.camera)
    }
    override func update() {
        gameObject.transform.position += speed * GameTimer.sharedTimer.deltaTime * dir
        if abs(gameObject.transform.position.x) > wall {
            let x = gameObject.transform.position.x
            speed *= -1
            gameObject.transform.position.x = x>0 ? wall : -wall
        }
    }
}

class MoveInCircle: Behaviour {
    var speed: Float = 0
    var radius: Float = 5
    init(gameObject: GameObject, radius: Float) {
        super.init(gameObject: gameObject)
        self.radius = radius
    }
    override func start() {
        
    }
    override func update() {
        let time = GameTimer.sharedTimer.time
        gameObject.transform.position = Float3(radius*sin(time/5), 0, 0)
    }
}

class RotateZ: Behaviour {
    var speed: Float = 0
    init(gameObject: GameObject, speed: Float) {
        super.init(gameObject: gameObject)
        self.speed = speed
    }
    override func start() {
        
    }
    override func update() {
        let deltaTime = GameTimer.sharedTimer.deltaTime
        gameObject.transform.rotate(angle: speed * deltaTime, axis: Float3(0, 1, 0))
    }
}
