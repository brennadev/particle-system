//
//  Ball.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/25/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

/// A single moving object in the scene
struct Particle {
    var position: float3
    var velocity: float3
    var acceleration: float3
    var radius: Float
    
    /// Stage of the animation - for fireworks only
    var stage: FireworkParticleStage
    
    
    init(position: float3, velocity: float3, acceleration: float3, radius: Float, stage: FireworkParticleStage = .beforeExplosion) {
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
        self.radius = radius
        self.stage = stage
    }
    
    
    // MARK: - Physics Motion Calculations
    /// Final velocity (vf) calculation, which updates `velocity`.
    mutating func updateFinalVelocity(for deltaT: Float) {
        velocity += acceleration * deltaT
    }
    
    
    /// Final position (xf) calculation, which updates `position`. Also updates `velocity` accordingly.
    mutating func updatePosition(for deltaT: Float) {
        //position = position + velocity * deltaT + 0.5 * acceleration * powf(deltaT, 2)
        position += velocity * deltaT
        updateFinalVelocity(for: deltaT)
    }
}
