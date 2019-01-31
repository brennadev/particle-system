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
    static var radius: Float = 1
    
    /// Stage of the animation - for fireworks only
    var stage: FireworkParticleStage
    var color: float4
    var lifespan: Float = 0
    var isAlive = true
    
    
    init(position: float3, velocity: float3, acceleration: float3, radius: Float, stage: FireworkParticleStage = .beforeExplosion, color: float4 = .white) {
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
        self.stage = stage
        self.color = color
    }
    
    
    // MARK: - Physics Motion Calculations
    /// Final velocity (vf) calculation, which updates `velocity`.
    mutating func updateFinalVelocity(for deltaT: Float) {
        velocity += acceleration * deltaT
    }
    
    
    /// Final position (xf) calculation, which updates `position`. Also updates `velocity` accordingly.
    mutating func updatePosition(for deltaT: Float) {
        //position = position + velocity * deltaT + 0.5 * acceleration * powf(deltaT, 2)
        updateFinalVelocity(for: deltaT)
        position += velocity * deltaT
        
    }
}
