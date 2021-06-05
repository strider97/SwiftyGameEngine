//
//  Core.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

import MetalKit

typealias Float3 = SIMD3<Float>
typealias Float4 = SIMD4<Float>
typealias Int3 = SIMD3<Int>

struct Vertex {
    var position: Float3
    var color: Float4
}

struct Uniforms {
    var M: Matrix4
    var V: Matrix4
    var P: Matrix4
    var eye: Float3
    var exposure: Float = 0.5
}

extension Float3 {
    var magnitude: Float {
        return sqrt((self * self).sum())
    }

    var normalized: Float3 {
        return self / magnitude
    }

    func cross(_ vector: Float3) -> Float3 {
        return Float3.cross(self, vector)
    }

    func dot(_ vector: Float3) -> Float {
        return Float3.dot(self, vector)
    }

    static func cross(_ left: Float3, _ right: Float3) -> Float3 {
        return Float3(
            left.y * right.z - left.z * right.y,
            -(left.x * right.z - left.z * right.x),
            left.x * right.y - left.y * right.x
        )
    }

    static func dot(_ left: Float3, _ right: Float3) -> Float {
        return (left * right).sum()
    }
}

extension Float2 {
    var magnitude: Float {
        return sqrt((self * self).sum())
    }
}

extension Matrix4 {
    static func viewMatrix(position: Float3, target: Float3, up _: Float3) -> Matrix4 {
        let cam = Camera(position: position, target: target)
        let r = cam.right
        let d = cam.front
        let u = cam.up
        let p = position

        let m1 = Matrix4(rows: [
            Float4(r, 0),
            Float4(u, 0),
            Float4(d, 0),
            Float4(0, 0, 0, 1),
        ])
        var m2 = Matrix4(1)
        m2.columns.3 = Float4(-p, 1)
        return m1 * m2
    }

    static func perspective(fov: Float, aspect: Float, nearDist: Float, farDist: Float, leftHanded: Bool = true) -> Matrix4 {
        guard fov > 0, aspect != 0 else {
            return Matrix4()
        }
        let frustumDepth = farDist - nearDist
        let oneOverDepth = 1.0 / frustumDepth
        var result = Matrix4(1)
        result[1][1] = 1 / tan(0.5 * fov)
        result[0][0] = (leftHanded ? 1 : -1) * result[1][1] / aspect
        result[2][2] = farDist * oneOverDepth
        result[3][2] = (-farDist * nearDist) * oneOverDepth
        result[2][3] = 1
        result[3][3] = 0
        return result
    }
}
