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

    override func viewDidLoad() {
        super.viewDidLoad()


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
        switch sender.label(forSegment: sender.selectedSegment) {
        case "Firework":
            break
        // TODO: add other simulation type
        default:
            break
        }
    }
    
    @IBAction func metalViewRotated(_ sender: NSRotationGestureRecognizer) {
        //print("rotation value: \(sender.rotationInDegrees)")
        
        // right now, it does some weird jumping back when a new gesture is initiated - thus checking the state
        // rotation value is cumulative; so that means the last angle needs to be saved
        
        switch sender.state {
        case .began:
            previousRotation = 0
        case .changed:
            break
        case .ended:
            break
        default:
            break
        }
        print("rotation: \(Float(sender.rotation) - previousRotation)")
        renderer.viewMatrix *= matrix4x4_rotation(radians: Float(sender.rotation) - previousRotation, axis: float3(0, 1, 0))
        print("viewMatrix: \(renderer.viewMatrix)")
        previousRotation = Float(sender.rotation)
    }
    
}
