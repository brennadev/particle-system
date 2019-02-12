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
    @IBOutlet weak var particleGenerationRateLabel: NSTextField!
    
    
    var renderer: Renderer!
    
    
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
    
    
    // MARK: - Control Changes
    @IBAction func modeSegmentedControlSegmentClicked(_ sender: NSSegmentedCell) {

        // handles resetting values
        renderer.particleSystem.particleSystemTypeChanged()
        
        switch sender.label(forSegment: sender.selectedSegment) {
        case "Fireworks":
            renderer.particleSystem.mode = .firework
        case "Water":
            renderer.particleSystem.mode = .water
        default:
            break
        }
    }
    
    @IBAction func particleGenerationRateSliderValueChanged(_ sender: NSSlider) {
        particleGenerationRateLabel.intValue = sender.intValue
        ParticleSystem.particleGenerationRate = Int(sender.intValue)
    }
    
    
    // MARK: - Moving the Scene
    @IBAction func metalViewRotated(_ sender: NSRotationGestureRecognizer) {
        if sender.state == .began {
            previousRotation = 0
        }
        
        //renderer.viewMatrix *= matrix4x4_rotation(radians: Float(sender.rotation) - previousRotation, axis: float3(0, 1, 0))
        renderer.viewMatrixRotation += Float(sender.rotation) - previousRotation
        previousRotation = Float(sender.rotation)
    }
    
    
    @IBAction func metalViewPanned(_ sender: NSPanGestureRecognizer) {
        if sender.state == .began {
            previousPanLocation = float2(0, 0)
        }
        
        let translation = sender.translation(in: mtkView)

        renderer.viewMatrixTranslation.x += (Float(translation.x) - previousPanLocation.x) * 0.01
        renderer.viewMatrixTranslation.z += (Float(translation.y) - previousPanLocation.y) * -0.01

        print("translation: \(renderer.viewMatrixTranslation)")
        
        previousPanLocation = float2(Float(translation.x), Float(translation.y))
    }   
}
