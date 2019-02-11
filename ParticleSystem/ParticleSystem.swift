//
//  ParticleSystem.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/31/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

/// Manage all the particles in use in the particle system. Will manage empty holes in the array from dead particles and fill them as needed when new particles are created.
struct ParticleSystem {
 
    init() {}
    
    /// Which simulation the particle system is currently showing. Default is `.firework`.
    var mode = ParticleSystemType.firework
    
    // MARK: - Particle Storage
    /// All the particles in the system. May contain dead particles, which can be checked by looking at an element's `isAlive` property.
    /// - note: Particles are removed by setting an individual element's `isAlive` property to `false`.
    private(set) var allParticles = [Particle]()
    
    /// Location in `allParticles` of the first new particle added
    private(set) var firstAddedParticleIndex: Int?
    
    
    // MARK: - Initial Generation
    
    /// If the type of thing being rendered changes, then everything must start all over
    mutating func particleSystemTypeChanged() {
        allParticles = []
    }
    
    
    /// Particles per second to generate
    static var particleGenerationRate = 1000
    /// Lifespan of single particle
    static let particleLifespan = 20
    
    /// Y location of floor plane - for collision detection
    static let floorY: Float = -8
    
    
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
        
        if Float.random(in: 0...1) < dt * Float(ParticleSystem.particleGenerationRate) {
            return numberOfParticlesRoundedDown + 1
        } else {
            return numberOfParticlesRoundedDown
        }
    }
    
    
    /// Generate the details about a water particle
    private func generateWaterParticle() -> Particle {
        
        // currently set up to pull a random value from a square
        let position = float3(Float.random(in: -2...2), 0, Float.random(in: -1...1))
        let velocity = float3(Float.random(in: -6...6), Float.random(in: 0...5), Float.random(in: -0.1...0.1))
        
        return Particle(position: position, velocity: velocity, acceleration: float3(0, -2, 0), radius: 1)
    }
    
    
    /// Generate the details about a firework particle
    private func generateFireworkParticle() -> Particle {
        
        // these values may need to be tweaked some once I can test
        
        // currently set up to pull a random value from a square
        let position = float3(Float.random(in: -1...1), 0, Float.random(in: 0...1))
        let velocity = float3(Float.random(in: -1...1), 6, Float.random(in: 0...0.1))
        
        
        return Particle(position: position, velocity: velocity, acceleration: float3(0, -1, 0), radius: 1)
    }
    
    
    // MARK: - Updates
    /// Perform updates for all particles
    mutating func updateParticles(for dt: Float) {
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
            // once it's just about to the highest point, the firework should explode
            if abs(particle.velocity.y) < 0.001 {
                allParticles[index].stage = .afterExplosion
                allParticles[index].velocity = float3(Float.random(in: -7...7), Float.random(in: 0.1...5), Float.random(in: 0...0.1))
                
            }
            
            allParticles[index].updatePosition(for: dt)
            allParticles[index].lifespan += dt
            
            if particle.lifespan > Float(ParticleSystem.particleLifespan) {
                
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
    
    
    /// Perform updates for all water particles
    private mutating func updateWaterParticles(for dt: Float) {
        
        var lastValidIndex = allParticles.count - 1
        
        for (index, particle) in allParticles.enumerated() where index <= lastValidIndex {
            
            
            // figure out which circular part (of the fountain) the particle is over
            let particleRadius = Float.maximum(abs(allParticles[index].position.x),
                                               abs(allParticles[index].position.z))
            
            
            
            switch particleRadius {
            // over inner (top) part of fountain
            case 0..<10:
                let particleFountainTopAdjustmentAmount: Float = 5
                
                if allParticles[index].position.y > ParticleSystem.floorY - particleFountainTopAdjustmentAmount {
                    allParticles[index].updatePosition(for: dt)
                } else {
                    allParticles[index].velocity *= -0.9
                    allParticles[index].updatePosition(for: dt)
                }
                
                // get particle out from below
                if allParticles[index].position.y < ParticleSystem.floorY - particleFountainTopAdjustmentAmount {
                    allParticles[index].position.y = ParticleSystem.floorY - particleFountainTopAdjustmentAmount
                }
                
                
            // over outer (bottom) part of fountain
            case 10..<20:
                let particleFountainBottomAdjustmentAmount: Float = 10
                
                if allParticles[index].position.y > ParticleSystem.floorY - particleFountainBottomAdjustmentAmount {
                    allParticles[index].updatePosition(for: dt)
                } else {
                    allParticles[index].velocity *= -0.9
                    allParticles[index].updatePosition(for: dt)
                }
                
                // get particle out from below
                if allParticles[index].position.y < ParticleSystem.floorY - particleFountainBottomAdjustmentAmount {
                    allParticles[index].position.y = ParticleSystem.floorY - particleFountainBottomAdjustmentAmount
                }
                
            // over floor
            default:
                
                let particleFloorAdjustmentAmount: Float = 50
                
                // when a particle hits the ground
                if allParticles[index].position.y > ParticleSystem.floorY - particleFloorAdjustmentAmount {
                    allParticles[index].updatePosition(for: dt)
                    
                    
                } else {
                    allParticles[index].velocity *= -0.9
                    allParticles[index].updatePosition(for: dt)
                }
                
                // get particle out from below
                if allParticles[index].position.y < ParticleSystem.floorY - particleFloorAdjustmentAmount {
                    allParticles[index].position.y = ParticleSystem.floorY - particleFloorAdjustmentAmount
                }
            }
            
            
            
            
            allParticles[index].lifespan += dt
            
            if particle.lifespan > Float(ParticleSystem.particleLifespan) {
                
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
