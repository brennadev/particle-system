//
//  matrix_float4x4Extension.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/27/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

import simd

// aka simd_float4x4
extension matrix_float4x4 {
    /// 4x4 identity matrix
    static var identity: matrix_float4x4 {
        return matrix_float4x4(float4(1, 0, 0, 0), float4(0, 1, 0, 0), float4(0, 0, 1, 0), float4(0, 0, 0,1))
    }
}
