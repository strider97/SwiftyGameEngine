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
    //    sphere = GameObject(modelName: "spheres")
    //    ring = GameObject(modelName: "ring")
    //    return [sphere, ring]
        var teapots: [GameObject] = []
        let nums = 6
        let scale: Float = 2.5
        for i in 0..<nums {
            for j in 0..<nums {
                let teapot = GameObject(modelName: "teapot")
                teapot.transform.translate(-Float(nums)/2 * Float3(scale, scale, 0.0) + Float3(Float(j)*scale, Float(i)*scale, 0))
                let mesh = teapot.getComponent(Mesh.self)!
                for (_, meshNodes) in mesh.meshNodes {
                    for meshNode in meshNodes {
                        let material = meshNode.material
                        material.roughness = Float(j)/Float(nums)
                        material.metallic = Float(i)/Float(nums)
                        material.baseColor = Float3(255, 255, 255)/255
                    }
                }
                teapots.append(teapot)
            }
        }
        return teapots
    }
    
    override func addPhysics() {
        
    }
    
    override func getSkybox() -> Skybox {
        return Skybox(textureName: "ground")
    }
    
    override func addBehaviour() {
    //    let _ = MoveInCircle(gameObject: sphere, radius: 10)
    }
    
    override func getCamera() -> Camera {
        return Camera(position: Float3(0, 0, 15), target: Float3(0, 0, 0))
    }
}
