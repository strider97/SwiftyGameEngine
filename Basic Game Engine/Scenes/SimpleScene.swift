//
//  SimpleScene.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 31/01/21.
//

import MetalKit

class SimpleScene: Scene {
    
    var blades: GameObject!
    
    override func getGameObjects() -> [GameObject] {
        let model = GameObject(modelName: "cerberus")
    //    blades = GameObject(modelName: "heliBlades")
        let mesh = model.getComponent(Mesh.self)!
        for (_, meshNodes) in mesh.meshNodes {
            for meshNode in meshNodes {
                let material = meshNode.material
            //    material.roughness *= material.roughness
            //    material.metallic = 0.0
            //    material.baseColor = Float3(1.0, 1.0, 0.7)
            }
        }
        return [model]
    }
    
    override func addPhysics() {
        
    }
    
    override func getSkybox() -> Skybox {
        return Skybox(textureName: "studio")
    }
    
    override func addBehaviour() {
    //    let _ = MoveInCircle(gameObject: blades, radius: 10)
    //    let _ = RotateZ(gameObject: blades, speed: 5)
    }
    
    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 15), target: Float3(0, 0, 0))
    }
}
