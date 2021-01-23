//
//  RenderPipelineState.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class MTLDeviceObject {
    static let sharedDevice = MTLDeviceObject()
    let device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var library: MTLLibrary?
    
    private init () {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        library = device?.makeDefaultLibrary()
    }
}
