//
//  Ball.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/25/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

/// Data about a single moving object in the scene
struct Particle {
    var position: float3
    var velocity: float3
    var acceleration: float3
    var radius: Float
    
    
    // MARK: - Physics Motion Calculations
    /// Final velocity (vf) calculation, which updates `velocity`.
    mutating func updateFinalVelocity(for deltaT: Float) {
        velocity = velocity + acceleration * deltaT
    }
    
    
    /// Final position (xf) calculation, which updates `position`. Also updates `velocity`.
    mutating func updatePosition(for deltaT: Float) {
        position = position + velocity * deltaT + 0.5 * acceleration * powf(deltaT, 2)
        updateFinalVelocity(for: deltaT)
    }
}
