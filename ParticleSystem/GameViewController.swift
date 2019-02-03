//
//  GameViewController.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/25/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import Cocoa
import MetalKit

// Our macOS specific view controller
class GameViewController: NSViewController {
    
    @IBOutlet var mtkView: MTKView!
    
    var renderer: Renderer!
    
    /// Which simulation the particle system is currently showing. Default is `.firework`.
    var mode = ParticleSystemType.firework
    
    var previousRotation: Float = 0
    var previousPanLocation = float2(0, 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        //mtkView.isPaused = true

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        // note to self: this is the resizing MTKViewDelegate method
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
    
    
    @IBAction func modeSegmentedControlSegmentClicked(_ sender: NSSegmentedCell) {
        // TODO: need to put some stuff in so things are properly regenerated
        switch sender.label(forSegment: sender.selectedSegment) {
        case "Firework":
            mode = .firework
        case "Water":
            mode = .water
        default:
            break
        }
    }
    
    @IBAction func startButtonClicked(_ sender: NSButton) {
        //mtkView.isPaused = false
    }
    
    
    @IBAction func metalViewRotated(_ sender: NSRotationGestureRecognizer) {
        if sender.state == .began {
            previousRotation = 0
        }
        
        renderer.viewMatrix *= matrix4x4_rotation(radians: Float(sender.rotation) - previousRotation, axis: float3(0, 1, 0))
        previousRotation = Float(sender.rotation)
    }
    
    
    @IBAction func metalViewPanned(_ sender: NSPanGestureRecognizer) {
        if sender.state == .began {
            previousPanLocation = float2(0, 0)
        }
        
        
        print("translation: \(sender.translation(in: mtkView))")
        renderer.viewMatrix *= matrix4x4_translation((Float(sender.translation(in: mtkView).x) - previousPanLocation.x) * 0.25,
                                                     0,
                                                     (Float(sender.translation(in: mtkView).y) - previousPanLocation.y) * 0.25)
        
        previousPanLocation = float2(Float(sender.location(in: mtkView).x), Float(sender.location(in: mtkView).y))
    }
    
}
