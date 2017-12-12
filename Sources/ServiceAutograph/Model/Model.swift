//
// Project «ServiceAutograph»
// Created by Jeorge Taflanidi
//


import Foundation
import Synopsis


struct Model: Equatable {
    let name: String
    let properties: [PropertyDescription]
    
    static func ==(left: Model, right: Model) -> Bool {
        return left.name        == right.name
            && left.properties  == right.properties
    }
}
