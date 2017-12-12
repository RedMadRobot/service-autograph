//
// Project «ServiceAutograph»
// Created by Jeorge Taflanidi
//


import Foundation
import Synopsis


struct Service {
    let comment:        String?
    let name:           String
    let parentProtocol: String
    let methods:        [MethodDescription]
}
