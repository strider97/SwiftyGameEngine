//
//  BasicScene.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/01/21.
//

import MetalKit

class BasicScene: Scene {
    var sphere: GameObject!
    var ring: GameObject!
    
    override func getGameObjects() -> [GameObject] {
        sphere = GameObject(modelName: "spheres")
        ring = GameObject(modelName: "ring")
        return [sphere, ring]
    }
    
    override func addPhysics() {
        
    }
    
    override func getSkybox() -> Skybox {
        return Skybox(textureName: "cambridge")
    }
    
    override func addBehaviour() {
    //    let _ = MoveInCircle(gameObject: sphere, radius: 10)
    }
    
    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 15), target: Float3(0, 0, 0))
    }
}
