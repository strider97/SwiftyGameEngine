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

extension GameView {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
    //    NotificationCenter.default.post(name: NSNotification.Name.keyIsPressed, object: event.characters)
        KeyboardEvents.pressDown(event.characters ?? "")
    }
    
    override func keyUp(with event: NSEvent) {
    //    NotificationCenter.default.post(name: NSNotification.Name.keyReleased, object: event.characters)
        KeyboardEvents.pressUp(event.characters ?? "")
    }
}
