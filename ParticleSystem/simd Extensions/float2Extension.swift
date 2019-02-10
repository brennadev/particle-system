//
//  float2Extension.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 2/10/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

extension float2 {
    /// For when a `float2` is needed as (x, z) - the second value stored
    var z: Float {
        get {
            return y
        } set {
            y = newValue
        }
    }
}
