//
//  GameView.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 24/01/21.
//

import MetalKit

class GameView: MTKView {
    
    @IBOutlet var normalBiasSlider: NSSlider!
    @IBOutlet var depthBiasSlider: NSSlider!
    @IBOutlet var exposureSlider: NSSlider!
    @IBOutlet var kaSlider: NSSlider!
    @IBOutlet var kdSlider: NSSlider!
    @IBOutlet var showLightProbes: NSButton!
    
    var currentScene: Scene!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = Device.sharedDevice.device
        delegate = SceneManager.sharedManager.currentScene
        currentScene = SceneManager.sharedManager.currentScene
        delegate?.mtkView(self, drawableSizeWillChange: CGSize(width: drawableSize.width, height: drawableSize.height))
        colorPixelFormat = Constants.pixelFormat
        depthStencilPixelFormat = .depth32Float
        clearColor = Colors.clearColor
        
        updateTrackingAreas()
        addTrackingArea(NSTrackingArea(coder: coder)!)
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        let trackingArea = NSTrackingArea(rect: bounds, options: options,
                                          owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    func addSliders() {
        currentScene.uniformSliders = [
            Constants.Labels.normalBias: normalBiasSlider,
            Constants.Labels.depthBias: depthBiasSlider,
            Constants.Labels.exposure: exposureSlider,
            Constants.Labels.ka: kaSlider,
            Constants.Labels.kd: kdSlider,
        ]
    }
    
    @IBAction func toggleShowProbes(_ sender: Any) {
        guard let checkBox = sender as? NSButton else { return }
        currentScene.showProbes = checkBox.state == .on
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

    override func mouseDown(with _: NSEvent) {
        Input.sharedInput.updateMouseClicked(clicked: true)
    }

    override func mouseUp(with _: NSEvent) {
        Input.sharedInput.updateMouseClicked(clicked: false)
    }

    override func mouseMoved(with _: NSEvent) {
        //   Input.sharedInput.updateMousePosition(pos: Float2(Float(event.locationInWindow.x), Float(event.locationInWindow.y)))
        //    NotificationCenter.default.post(name: NSNotification.Name.mouseMoved, object: nil)
    }

    override func mouseExited(with _: NSEvent) {
        Input.sharedInput.firstMouseInteraction = true
    }
}
