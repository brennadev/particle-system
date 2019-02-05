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
 
    init() {
        
    }
    
    /// Which simulation the particle system is currently showing. Default is `.firework`.
    var mode = ParticleSystemType.firework
    
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
    
    /// If the type of thing being rendered changes, then everything must start all over
    mutating func particleSystemTypeChanged() {
        allParticles = []
        
        
        
    }
    
    
    /// Particles per second to generate
    private let particleGenerationRate = 10
    
    
    /// How many new particles to generate for the given frame
    func numberOfParticlesToGenerate(in dt: Float) -> Int {
        
        
        let numberOfParticles = Float(particleGenerationRate) * dt
        let numberOfParticlesRoundedDown = Int(numberOfParticles.rounded(.down))
        // not sure where this is supposed to be used
        let numberOfParticlesFraction = numberOfParticles - Float(numberOfParticlesRoundedDown)
        
        // TODO: don't know what the random range should be
        if Float.random(in: 0...1) < dt * Float(particleGenerationRate) {
            return numberOfParticlesRoundedDown + 1
        } else {
            return numberOfParticlesRoundedDown
        }
    }
    
    
    /// Generate the details about a water particle
    func generateWaterParticle() -> Particle {
        // TODO: fill in
        
        // currently set up to pull a random value from a square
        let position = float3(Float.random(in: 0...2), 0, Float.random(in: 0...2))
        let velocity = float3(Float.random(in: 0...1), 4, Float.random(in: 0...1))
        
        
        return Particle(position: position, velocity: velocity, acceleration: float3(0, -9.8, 0), radius: 1)
    }
    
    
    /// Generate the details about a firework particle
    func generateFireworkParticle() -> Particle {
        // TODO: fill in
        
        // start with the particles all having the same x/z, then once a particle reaches a certain height, then have the x/z change (the firework exploding)
        // the particles will start out in a straight line going in the y direction - thus don't want a lot of perturbation in the x/z directions
        
        
        // these values may need to be tweaked some once I can test
        
        // currently set up to pull a random value from a square
        let position = float3(Float.random(in: 0...1), 0, Float.random(in: 0...1))
        let velocity = float3(Float.random(in: 0...1), 4, Float.random(in: 0...1))
        
        
        return Particle(position: position, velocity: velocity, acceleration: float3(0, -9.8, 0), radius: 1)
    }
    
    func updateWaterParticles() {
        
    }
    
    func updateFireworkParticles() {
        
    }
    
}
