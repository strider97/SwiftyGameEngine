//
//  SimpleScene.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/01/21.
//

import MetalKit

class SimpleScene: Scene {
    
    var blades: GameObject!
    var model: GameObject!
    var model2: GameObject!
    var model3: GameObject!
    var model4: GameObject!
    
    override func getGameObjects() -> [GameObject] {
        model = GameObject(modelName: "plane")
        model2 = GameObject(modelName: "coffeeCart")
        model3 = GameObject(modelName: "vase")
        model4 = GameObject(modelName: "barrel")
        
        model.transform.scale(Float3(repeating: 3))
        model2.transform.scale(Float3(repeating: 2))
        model3.transform.translate(Float3(20, 0, 0))
        model3.transform.scale(Float3(repeating: 2))
        model4.transform.translate(Float3(20, 0, 0))
        return [model, model2, model3]
    }
    
    override func addPhysics() {
        
    }
    
    override func getSkybox() -> Skybox {
        return Skybox(textureName: "park")
    }
    
    override func addBehaviour() {
    //    let _ = MoveInCircle(gameObject: model2, radius: 15)
    //    let _ = RotateZ(gameObject: model, speed: 0.1)
    }
    
    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 15), target: Float3(0, 0, 0))
    }
}
