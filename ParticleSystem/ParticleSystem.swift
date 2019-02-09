//
//  ParticleSystem.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/31/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

struct MovedParticle {
    var before: Int
    var after: Int
}

/// Singleton to manage all the particles in use in the particle system. Will manage empty holes in the array from dead particles and fill them as needed when new particles are created.
struct ParticleSystem {
 
    init() {}
    
    /// Which simulation the particle system is currently showing. Default is `.firework`.
    var mode = ParticleSystemType.firework
    
    // MARK: - Particle Storage
    /// All the particles in the system. May contain dead particles, which can be checked by looking at an element's `isAlive` property.
    /// - note: Particles are removed by setting an individual element's `isAlive` property to `false`.
    private(set) var allParticles = [Particle]()
    
    
    /// All particles that have been moved in the `allParticles`
    private(set) var movedParticles = [MovedParticle]()
    
    
    /// Location in `allParticles` of the first new particle added
    private(set) var firstAddedParticleIndex: Int?
    
    
    
    // MARK: - Initial Generation
    
    /// If the type of thing being rendered changes, then everything must start all over
    mutating func particleSystemTypeChanged() {
        allParticles = []
        
        // TODO: not sure if anything else needs to go here since then the updates just need to start occurring
    }
    
    
    /// Particles per second to generate
    static let particleGenerationRate = 10
    /// Lifespan of single particle
    static let particleLifespan = 10
    
    
    mutating func addParticles(for dt: Float) {
        let particleCountToAdd = numberOfParticlesToGenerate(in: dt)
        firstAddedParticleIndex = allParticles.count
        
        switch mode {
        case .firework:
            for _ in 0..<particleCountToAdd {
                allParticles.append(generateFireworkParticle())
                
            }
        case .water:
            for _ in 0..<particleCountToAdd {
                allParticles.append(generateWaterParticle())
            }
        }
    }
    
    /// How many new particles to generate for the given frame
    private func numberOfParticlesToGenerate(in dt: Float) -> Int {
        
        let numberOfParticles = Float(ParticleSystem.particleGenerationRate) * dt
        let numberOfParticlesRoundedDown = Int(numberOfParticles.rounded(.down))
        // not sure where this is supposed to be used
        let numberOfParticlesFraction = numberOfParticles - Float(numberOfParticlesRoundedDown)
        
        // TODO: don't know what the random range should be
        if Float.random(in: 0...1) < dt * Float(ParticleSystem.particleGenerationRate) {
            return numberOfParticlesRoundedDown + 1
        } else {
            return numberOfParticlesRoundedDown
        }
    }
    
    
    /// Generate the details about a water particle
    private func generateWaterParticle() -> Particle {
        // TODO: fill in
        
        // currently set up to pull a random value from a square
        let position = float3(Float.random(in: 0...2), 0, Float.random(in: 0...2))
        let velocity = float3(Float.random(in: 0...1), 4, Float.random(in: 0...1))
        
        
        return Particle(position: position, velocity: velocity, acceleration: float3(0, -9.8, 0), radius: 1)
    }
    
    
    /// Generate the details about a firework particle
    private func generateFireworkParticle() -> Particle {
        
        // these values may need to be tweaked some once I can test
        
        // currently set up to pull a random value from a square
        let position = float3(Float.random(in: 0...1), 0, Float.random(in: 0...1))
        let velocity = float3(Float.random(in: 0...1), 4, Float.random(in: 0...1))
        
        
        return Particle(position: position, velocity: velocity, acceleration: float3(0, -1, 0), radius: 1)
    }
    
    
    // MARK: - Updates
    /// Perform updates for all particles
    mutating func updateParticles(for dt: Float) {
        movedParticles = []
        
        switch mode {
        case .firework:
            updateFireworkParticles(for: dt)
        case .water:
            updateWaterParticles(for: dt)
        }
    }
    
    
    /// Perform updates for all firework particles
    private mutating func updateFireworkParticles(for dt: Float) {
        
        var lastValidIndex = allParticles.count - 1
        
        for (index, particle) in allParticles.enumerated() where index <= lastValidIndex {
            if particle.isAlive {
                // once it's just about to the highest point, the firework should explode
                if abs(particle.velocity.y) < 0.001 {
                    allParticles[index].stage = .afterExplosion
                    allParticles[index].velocity = float3(Float.random(in: 0.1...5), Float.random(in: 0.1...5), Float.random(in: 0.1...5))
                    
                }
                
                allParticles[index].updatePosition(for: dt)
                allParticles[index].lifespan += dt
                
                // TODO: this value may need to be tweaked some
                if particle.lifespan > 10 {
                    allParticles[index].isAlive = false
                    movedParticles.append(MovedParticle(before: allParticles.count - 1, after: index))
                    
                    // if statement here because otherwise, you're trying to assign to an index that was just removed
                    if index != lastValidIndex {
                        allParticles[index] = allParticles.removeLast()
                    } else {
                        allParticles.removeLast()
                    }
                    
                    lastValidIndex -= 1
                }
            }
        }
    }
    
    
    /// Perform updates for all water particles
    private mutating func updateWaterParticles(for dt: Float) {
        
        var lastValidIndex = allParticles.count - 1
        
        for (index, particle) in allParticles.enumerated() where index <= lastValidIndex {
            if particle.isAlive {
                allParticles[index].updatePosition(for: dt)
                allParticles[index].lifespan += dt
                
                // TODO: this value may need to be tweaked some
                if particle.lifespan > 10 {
                    allParticles[index].isAlive = false
                    movedParticles.append(MovedParticle(before: allParticles.count - 1, after: index))
                    
                    // if statement here because otherwise, you're trying to assign to an index that was just removed
                    if index != lastValidIndex {
                        allParticles[index] = allParticles.removeLast()
                    } else {
                        allParticles.removeLast()
                    }
                    
                    lastValidIndex -= 1
                }
            }
        }
    }
    
}
