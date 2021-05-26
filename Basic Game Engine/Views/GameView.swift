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
        self.delegate = SceneManager.sharedManager.currentScene
        delegate?.mtkView(self, drawableSizeWillChange: CGSize(width: self.drawableSize.width/2, height: self.drawableSize.height/2))
        colorPixelFormat = Constants.pixelFormat
        depthStencilPixelFormat = .depth32Float
        clearColor = Colors.clearColor
        
        updateTrackingAreas()
        addTrackingArea(NSTrackingArea(coder: coder)!)
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options,
                                          owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
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
    
    override func mouseDown(with event: NSEvent) {
        Input.sharedInput.updateMouseClicked(clicked: true)
    }
    
    override func mouseUp(with event: NSEvent) {
        Input.sharedInput.updateMouseClicked(clicked: false)
    }
    
    override func mouseMoved(with event: NSEvent) {
     //   Input.sharedInput.updateMousePosition(pos: Float2(Float(event.locationInWindow.x), Float(event.locationInWindow.y)))
    //    NotificationCenter.default.post(name: NSNotification.Name.mouseMoved, object: nil)
    }
    
    override func mouseExited(with event: NSEvent) {
        Input.sharedInput.firstMouseInteraction = true
    }
}
