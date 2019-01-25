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
}
