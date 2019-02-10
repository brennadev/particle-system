//
//  ColorChangeState.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 2/10/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

enum ColorChangeState {
    case RedConstantGreenUp
    case RedDownGreenConstant
    case GreenConstantBlueUp
    case GreenDownBlueConstant
    case BlueConstantRedUp
    case BlueDownRedConstant
    
    var next: ColorChangeState {
        switch self {
        case .RedConstantGreenUp:
            return .RedDownGreenConstant
        case .RedDownGreenConstant:
            return .GreenConstantBlueUp
        case .GreenConstantBlueUp:
            return .GreenDownBlueConstant
        case .GreenDownBlueConstant:
            return .BlueConstantRedUp
        case .BlueConstantRedUp:
            return .BlueDownRedConstant
        case .BlueDownRedConstant:
            return .RedConstantGreenUp
        }
    }
}
