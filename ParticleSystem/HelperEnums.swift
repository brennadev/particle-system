//
//  HelperEnums.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/28/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

// Little stuff that controls things such as the mode the particle system is in

/// Which particle system we're viewing
enum ParticleSystemType {
    case firework
    case water
    
    var scale: Float {
        switch self {
        case .firework:
            return 0.04
        case .water:
            return 0.02
        }
    }
}

enum FireworkParticleStage {
    case beforeExplosion
    case afterExplosion
}
