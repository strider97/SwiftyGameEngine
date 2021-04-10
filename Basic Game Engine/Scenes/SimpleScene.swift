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
    
    override func getGameObjects() -> [GameObject] {
        model = GameObject(modelName: "plane")
        model2 = GameObject(modelName: "cylinder")
        
        model.transform.translate(Float3(0, -2, 0))
   //     model2.transform.translate(Float3(0, 100, 0))
        model.transform.scale(Float3(repeating: 3))
        model2.transform.scale(Float3(repeating: 3))
   //     model2.transform.rotate(angle: -MathConstants.PI.rawValue/2, axis: Float3(1, 0, 0))
   //     model2.transform.scale(Float3(repeating: 0.8))
   //     model2.transform.translate(Float3(0, -15, 0))
        return [model, model2]
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
