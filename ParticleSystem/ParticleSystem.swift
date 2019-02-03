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
 
    // MARK: - Particle Storage
    /// All the particles in the system. May contain dead particles, which can be checked by looking at an element's `isAlive` property.
    /// - note: Particles are removed by setting an individual element's `isAlive` property to `false`.
    private(set) var allParticles = [Particle]()
    
    /// All available indices due to dead particles
    private var emptyIndices = [Int]()
    
    /// Add a new particle into the system
    mutating func addParticle(newParticle: Particle) {
        // when there's an available space due to a dead particle, use it
        if let last = emptyIndices.last {
            allParticles[last] = newParticle
            emptyIndices.removeLast(1)
         
        // if not, then just append it on the end
        } else {
            allParticles.append(newParticle)
        }
    }
    
    
    // MARK: - Initial Generation
    /// Particles per second to generate
    private let particleGenerationRate = 10
    
    func numberOfParticlesToGenerate(in dt: Float) -> Int {
        
        
        let numberOfParticles = Float(particleGenerationRate) * dt
        let numberOfParticlesRoundedDown = Int(numberOfParticles.rounded(.down))
        // not sure where this is supposed to be used
        let numberOfParticlesFraction = numberOfParticles - Float(numberOfParticlesRoundedDown)
        
        if Float.random(in: 0...100) < dt * Float(particleGenerationRate) {
            return numberOfParticlesRoundedDown + 1
        } else {
            return numberOfParticlesRoundedDown
        }
        
    }
}
