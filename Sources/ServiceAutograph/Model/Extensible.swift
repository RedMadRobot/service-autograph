//
// Project «ServiceAutograph»
// Created by Jeorge Taflanidi
//


import Foundation
import Synopsis


extension ClassDescription {
    var inheritesDecodable: Bool {
        return inheritedTypes.contains("Decodable") || inheritedTypes.contains("Codable")
    }
}


extension StructDescription {
    var inheritesDecodable: Bool {
        return inheritedTypes.contains("Decodable") || inheritedTypes.contains("Codable")
    }
}


extension PropertyDescription {
    var hasJsonKey: Bool {
        return annotations.contains(annotationName: "json")
    }
    
    var jsonKey: String? {
        return annotations["json"]?.value
    }
}


extension ProtocolDescription {
    var isService: Bool {
        return annotations.contains(annotationName: "service")
    }
    
    var serviceName: String {
        return annotations["service"]?.value ?? name + "GEN"
    }
}


extension TypeDescription {
    var plural: Bool {
        switch self {
            case .array, .map: return true
            default: return false
        }
    }
    
    var serviceCallReturnType: ServiceCallReturnType {
        switch self {
            case .generic(let name, let constraints):
                let cancelable: Bool
                
                if name == "ServiceCall" {
                    cancelable = false
                } else if name == "CancelableServiceCall" {
                    cancelable = true
                } else {
                    return ServiceCallReturnType.error
                }
            
                let payloadType: TypeDescription
            
                if let first: TypeDescription = constraints.first {
                    payloadType = first
                } else {
                    return ServiceCallReturnType.error
                }
            
                if cancelable {
                    return ServiceCallReturnType.cancelableServiceCall(payloadType: payloadType)
                } else {
                    return ServiceCallReturnType.serviceCall(payloadType: payloadType)
                }
            
            default: return ServiceCallReturnType.error
        }
    }
    
    enum ServiceCallReturnType {
        case serviceCall(payloadType: TypeDescription)
        case cancelableServiceCall(payloadType: TypeDescription)
        case error
    }
}


extension Annotation {
    var requestInterceptorName: String? {
        return self.name == "requestInterceptor" ? self.value : nil
    }
    
    var responseInterceptorName: String? {
        return self.name == "responseInterceptor" ? self.value : nil
    }
}


extension ArgumentDescription {
    func annotationValue(_ annotationName: String) -> String? {
        if let annotation: Annotation = annotations[annotationName] {
            return annotation.value ?? bodyName
        }
        return nil
    }
    
    var urlPlaceholderName: String? {
        if let urlAnnotation: Annotation = annotations["url"] {
            return urlAnnotation.value ?? bodyName
        }
        return nil
    }
}


extension Sequence where Element == ArgumentDescription {
    
    func annotatedWith(_ annotationName: String) -> [String] {
        return self.flatMap { (argument: ArgumentDescription) -> String? in
            if let annotationValue: String = argument.annotationValue(annotationName) {
                return "\"\(annotationValue)\": \(argument.bodyName)"
            }
            return nil
        }
    }
    
}


extension Array where Element == String {
    
    var dictString: String {
        if self.isEmpty {
            return ":"
        }
        return self.joined(separator: ", ")
    }
    
}
