//
//  BasicScene.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/01/21.
//

import MetalKit

class BasicScene: Scene {
    var spheres: GameObject!
    var monkey: GameObject!
    
    override func getGameObjects() -> [GameObject] {
        spheres = GameObject(modelName: "spheres")
        monkey = GameObject(modelName: "teapot")
        return [spheres, monkey]
    }
    
    override func addPhysics() {
        
    }
    
    override func addBehaviour() {
        let _ = MoveInCircle(gameObject: monkey, radius: 10)
    }
    
    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 15), target: Float3(0, 0, 0))
    }
}
