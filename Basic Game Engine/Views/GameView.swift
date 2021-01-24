//
//  GameView.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class GameView: MTKView {
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = Device.sharedDevice.device
        colorPixelFormat = Constants.pixelFormat
        delegate = SceneManager.sharedManager.currentScene
        clearColor = Colors.clearColor
    }
}
