//
//  ParticleSystem.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/31/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

/// Singleton to manage all the particles in use in the particle system. Will manage empty holes in the array from dead particles and fill them as needed when new particles are created.
struct ParticleSystem {
    /// Only here to prevent instances of the struct from being created
    private init() {
    }
    
    /// All the particles in the system. May contain dead particles, which can be checked by looking at an element's `isAlive` property.
    /// - note: Particles are removed by setting an individual element's `isAlive` property to `false`.
    private(set) static var allParticles = [Particle]()
    
    /// All available indices due to dead particles
    private static var emptyIndices = [Int]()
    
    /// Add a new particle into the system
    static func addParticle(newParticle: Particle) {
        // when there's an available space due to a dead particle, use it
        if let last = emptyIndices.last {
            allParticles[last] = newParticle
            emptyIndices.removeLast(1)
         
        // if not, then just append it on the end
        } else {
            allParticles.append(newParticle)
        }
    }
}
