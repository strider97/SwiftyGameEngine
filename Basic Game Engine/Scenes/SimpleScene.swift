//
//  SimpleScene.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/01/21.
//

import MetalKit

class SimpleScene: Scene {
    var spheres2: GameObject!
    
    override func getGameObjects() -> [GameObject] {
        spheres2 = GameObject(modelName: "teapot")
        return [spheres2]
    }
    
    override func addPhysics() {
        
    }
    
    override func addBehaviour() {
        let _ = Move(gameObject: spheres2, speed: 4)
    }
    
    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 15), target: Float3(0, 0, 0))
    }
}
