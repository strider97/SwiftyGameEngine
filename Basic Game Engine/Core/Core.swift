//
//  Core.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

infix operator >< : MultiplicationPrecedence
extension Float3 {
    var normalized: Float3 {
        return self/sqrt((self*self).sum())
    }
    
    func cross(_ vector: Float3) -> Float3 {
        return Float3.cross(self, vector)
    }
    
    func dot(_ vector: Float3) -> Float {
        return Float3.dot(self, vector)
    }
    
    static func cross (_ left: Float3, _ right: Float3) -> Float3 {
        return Float3(
            left.y*right.z - left.z*right.y,
            -(left.x*right.z - left.z*right.x),
            left.x*right.y - left.y*right.x
        )
    }
    
    static func dot (_ left: Float3, _ right: Float3) -> Float {
        return (left * right).sum()
    }
}

extension Matrix4 {
    static func viewMatrix (position: Float3, target: Float3, up: Float3) -> Matrix4 {
        let cam = Camera(position: position, target: target)
        let r = cam.right
        let d = cam.front
        let u = cam.up
        let p = position
        
        let m1 = Matrix4(rows: [
            Float4(r, 0),
            Float4(u, 0),
            Float4(d, 0),
            Float4(0, 0, 0, 1)
        ])
        var m2 = Matrix4(1)
        m2.columns.3 = Float4(-p, 1)
        return m1*m2
    }
}
