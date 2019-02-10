//
//  float4Extension.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/26/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

extension float4 {
    init(xyz: float3, w: Float = 1) {
        self.init(xyz.x, xyz.y, xyz.z, w)
    }
    
    static var white: float4 {
        return float4(1, 1, 1, 1)
    }
    
    var red: Float {
        get {
            return x
        } set {
            x = newValue
        }
    }
    
    var green: Float {
        get {
            return y
        } set {
            y = newValue
        }
    }
    
    var blue: Float {
        get {
            return z
        } set {
            z = newValue
        }
    }
    
    var alpha: Float {
        get {
            return w
        } set {
            w = newValue
        }
    }
}
