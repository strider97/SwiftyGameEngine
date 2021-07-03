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
        model = GameObject(modelName: "pillarRoom")
        return [model]
    }

    override func addPhysics() {}

    override func getSkybox() -> Skybox {
        return Skybox(textureName: "cambridge")
    }

    override func addBehaviour() {
        //    let _ = MoveInCircle(gameObject: model2, radius: 15)
        //    let _ = RotateZ(gameObject: model, speed: 0.1)
    }

    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 2, 4), target: Float3(0, 2, 0))
    }
}
