//
//  ViewController.swift
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 22/01/21.
//

import Cocoa

class GameViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let gameView = view as? GameView else { return }
        gameView.addSliders()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
