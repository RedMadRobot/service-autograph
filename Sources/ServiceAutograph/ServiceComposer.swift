//
// Project «ServiceAutograph»
// Created by Jeorge Taflanidi
//


import Foundation
import Autograph
import Synopsis


struct ServiceComposer {
    
    static func composeServices(forSynopsis synopsis: Synopsis, output: String) throws -> [Implementation] {
        let services: [Service] =
            synopsis.protocols
                .filter { $0.isService }
                .map { Service(comment: $0.comment, name: $0.serviceName, parentProtocol: $0.name, methods: $0.methods) }
        
        let implementations: [Implementation] =
            try services.map { try composeService($0, output: output) }
        
        return implementations + [composeBase(output: output)]
    }
    
}
    
private extension ServiceComposer {
    
    static func composeBase(output: String) -> Implementation {
        return Implementation(
            filePath: output + "/Service.swift",
            sourceCode: serviceBase
        )
    }
    
    static func composeService(_ service: Service, output: String) throws -> Implementation {
        let implementedMethods: [MethodDescription] =
            try implementMethods(service.methods)
        
        let serviceClass = ClassDescription.template(
            comment: service.comment,
            accessibility: Accessibility.internal,
            name: service.name,
            inheritedTypes: ["WebService", service.parentProtocol],
            properties: [],
            methods: implementedMethods
        )
        
        let sourceCode: String = """
            import Foundation
            import HTTPTransport


            """ + serviceClass.verse
        
        return Implementation(
            filePath: output + "/" + service.name + ".swift",
            sourceCode: sourceCode
        )
    }
    
    static func implementMethods(_ methods: [MethodDescription]) throws -> [MethodDescription] {
        return try methods.map { try implementMethod($0) }
    }
    
    static func implementMethod(_ method: MethodDescription) throws -> MethodDescription {
        guard
            let returnType: TypeDescription = method.returnType
        else {
            throw XcodeMessage(
                declaration: method.declaration,
                message: "[ServiceAutograph] Service method must return a ServiceCall<> or a CancelableServiceCall<>"
            )
        }
        
        let body: String
        
        let serviceReturnType: TypeDescription.ServiceCallReturnType = returnType.serviceCallReturnType
        switch serviceReturnType {
            case .error:
                throw XcodeMessage(
                    declaration: method.declaration,
                    message: "[ServiceAutograph] Service method must return a ServiceCall<> or a CancelableServiceCall<>"
                )
            
            case .serviceCall(let payloadType):
                body = composeServiceCallBody(payloadType, annotations: method.annotations, arguments: method.arguments, cancelable: false)
            
            case .cancelableServiceCall(let payloadType):
                body = composeServiceCallBody(payloadType, annotations: method.annotations, arguments: method.arguments, cancelable: true)
        }
        
        return try MethodDescription.template(
            comment: method.comment,
            accessibility: method.accessibility,
            name: method.name,
            arguments: method.arguments,
            returnType: method.returnType,
            kind: FunctionDescription.Kind.instance,
            body: body
        )
    }
    
    static func composeServiceCallBody(
        _ payloadType: TypeDescription,
        annotations: [Annotation],
        arguments: [ArgumentDescription],
        cancelable: Bool
    ) -> String {
        // PARAMETERS
        let jsonArgumentsStr:  String = arguments.annotatedWith("json").dictString
        let queryArgumentsStr: String = arguments.annotatedWith("query").dictString
        let plistArgumentsStr: String = arguments.annotatedWith("plist").dictString
        
        // HEADERS
        let headersStr: String = arguments.annotatedWith("header").dictString
        
        // INTERCEPTORS
        let requestInterceptorsStr:  String = annotations.flatMap { $0.requestInterceptorName }.map { $0 + "()" }.joined(separator: ", ")
        let responseInterceptorsStr: String = annotations.flatMap { $0.responseInterceptorName }.map { $0 + "()" }.joined(separator: ", ")
        
        // PAYLOAD TYPE
        let payloadTypeStr: String = payloadType.verse
        let firstStr: String
        if payloadType.plural {
            firstStr = ""
        } else if case TypeDescription.optional = payloadType {
            firstStr = ".first"
        } else {
            firstStr = ".first!"
        }
        
        // ENDPOINT
        var endpointStr: String = annotations["url"]?.value ?? ""
        arguments.forEach { (argument: ArgumentDescription) in
            guard let urlPlaceholderName: String = argument.urlPlaceholderName
            else { return }
            
            endpointStr = endpointStr.replacingOccurrences(of: "{\(urlPlaceholderName)}", with: "\\(\(argument.bodyName))")
        }
        
        // METHOD
        var requestMethodStr: String = "get"
        for requestMethod in [ "get", "post", "put", "patch", "delete", "head", "options" ] {
            if annotations.contains(annotationName: requestMethod) {
                requestMethodStr = requestMethod
            }
        }
        
        // PARSE STATEMENT
        let parseStr:           String
        let httpResponseStr:    String
        if case TypeDescription.void = payloadType {
            parseStr = "()"
            httpResponseStr = "_"
        } else {
            parseStr = "self.objectParser(forURL: request.endpoint).parse(any: httpResponse.body)\(firstStr)"
            httpResponseStr = "let httpResponse"
        }
        
        if cancelable {
            return cancelableServiceCallBody(
                payloadTypeStr: payloadTypeStr,
                jsonArgumentsStr: jsonArgumentsStr,
                queryArgumentsStr: queryArgumentsStr,
                plistArgumentsStr: plistArgumentsStr,
                requestMethodStr: requestMethodStr,
                endpointStr: endpointStr,
                headersStr: headersStr,
                requestInterceptorsStr: requestInterceptorsStr,
                responseInterceptorsStr: responseInterceptorsStr,
                httpResponseStr: httpResponseStr,
                parseStr: parseStr
            )
        } else {
            return serviceCallBody(
                payloadTypeStr: payloadTypeStr,
                jsonArgumentsStr: jsonArgumentsStr,
                queryArgumentsStr: queryArgumentsStr,
                plistArgumentsStr: plistArgumentsStr,
                requestMethodStr: requestMethodStr,
                endpointStr: endpointStr,
                headersStr: headersStr,
                requestInterceptorsStr: requestInterceptorsStr,
                responseInterceptorsStr: responseInterceptorsStr,
                httpResponseStr: httpResponseStr,
                parseStr: parseStr
            )
        }
    }
    
    static func serviceCallBody(
        payloadTypeStr: String,
        jsonArgumentsStr: String,
        queryArgumentsStr: String,
        plistArgumentsStr: String,
        requestMethodStr: String,
        endpointStr: String,
        headersStr: String,
        requestInterceptorsStr: String,
        responseInterceptorsStr: String,
        httpResponseStr: String,
        parseStr: String
    ) -> String {
        return """
        return createCall() { () -> ServiceCallResult<\(payloadTypeStr)> in
            let jsonArguments: HTTPRequestParameters = self.fillHTTPRequestParameters(
                self.jsonParameters,
                with: [\(jsonArgumentsStr)]
            )
        
            let queryArguments: HTTPRequestParameters = self.fillHTTPRequestParameters(
                self.urlParameters,
                with: [\(queryArgumentsStr)]
            )
        
            let plistArguments: HTTPRequestParameters = self.fillHTTPRequestParameters(
                self.plistParameters,
                with: [\(plistArgumentsStr)]
            )
        
            let request = HTTPRequest(
                httpMethod: HTTPRequest.HTTPMethod.\(requestMethodStr),
                endpoint: "\(endpointStr)",
                headers: [\(headersStr)],
                parameters: [jsonArguments, queryArguments, plistArguments],
                requestInterceptors: [\(requestInterceptorsStr)],
                responseInterceptors: [\(responseInterceptorsStr)],
                base: self.baseRequest
            )
        
            let result: HTTPTransport.Result = self.transport.send(request: request)
        
            switch result {
                case .success(\(httpResponseStr)):
                    let payload: \(payloadTypeStr) = \(parseStr)
                    return ServiceCallResult.success(payload: payload)
                case .failure(let error):
                    return ServiceCallResult.failure(error: error)
            }
        }
        """
    }
    
    static func cancelableServiceCallBody(
        payloadTypeStr: String,
        jsonArgumentsStr: String,
        queryArgumentsStr: String,
        plistArgumentsStr: String,
        requestMethodStr: String,
        endpointStr: String,
        headersStr: String,
        requestInterceptorsStr: String,
        responseInterceptorsStr: String,
        httpResponseStr: String,
        parseStr: String
    ) -> String {
        return """
        return createCancelableCall() { (this: CancelableServiceCall<\(payloadTypeStr)>, callback: @escaping (ServiceCallResult<\(payloadTypeStr)>) -> ()) in
            let jsonArguments: HTTPRequestParameters = self.fillHTTPRequestParameters(
                self.jsonParameters,
                with: [\(jsonArgumentsStr)]
            )
        
            let queryArguments: HTTPRequestParameters = self.fillHTTPRequestParameters(
                self.urlParameters,
                with: [\(queryArgumentsStr)]
            )
        
            let plistArguments: HTTPRequestParameters = self.fillHTTPRequestParameters(
                self.plistParameters,
                with: [\(plistArgumentsStr)]
            )
        
            let request = HTTPRequest(
                httpMethod: HTTPRequest.HTTPMethod.\(requestMethodStr),
                endpoint: "\(endpointStr)",
                headers: [\(headersStr)],
                parameters: [jsonArguments, queryArguments, plistArguments],
                requestInterceptors: [\(requestInterceptorsStr)],
                responseInterceptors: [\(responseInterceptorsStr)],
                base: self.baseRequest
            )
        
            let httpCall: HTTPCall = self.transport.send(request: request) { (result: HTTPTransport.Result) in
                switch result {
                    case .success(\(httpResponseStr)):
                        let payload: \(payloadTypeStr) = \(parseStr)
                        callback(ServiceCallResult.success(payload: payload))
                    case .failure(let error):
                        callback(ServiceCallResult.failure(error: error))
                }
            }
        
            this.cancelClosure = {
                httpCall.cancel()
            }
        }
        """
    }
    
}


let serviceBase = """
import Foundation
import HTTPTransport


/**
 Result, returned by `ServiceCall`

 - seealso: `ServiceCall`, `CancelableServiceCall`
 */
enum ServiceCallResult<Payload> {
    case success(payload: Payload)
    case failure(error: NSError)
}


/**
 Wrapper over service method. Might be called synchronously or asynchronously.
 */
class ServiceCall<Payload> {

    /**
     Signature for closure, which wraps service method logic.
     */
    typealias Main = () -> ServiceCallResult<Payload>

    /**
     Completion callback signature.
     */
    typealias Callback = (_ result: ServiceCallResult<Payload>) -> ()

    /**
     Cancel closure signature.
     */
    typealias Cancel = () -> ()

    /**
     Background queue, where wrapped service logic will be performed.
     */
    let operationQueue: OperationQueue

    /**
     Completion callback queue.
     */
    let callbackQueue: OperationQueue

    /**
     Closure, which wraps service method logic.
     */
    let main: Main

    /**
     Result.
     */
    var result: ServiceCallResult<Payload>?

    /**
     Initializer.

     - Parameters:
     - operationQueue: background queue, where wrapped service logic will be performed
     - callbackQueue: completion callback queue
     - main: closure, which wraps service method logic.
     */
    init(
        operationQueue: OperationQueue,
        callbackQueue: OperationQueue,
        main: @escaping Main
    ) {
        self.operationQueue = operationQueue
        self.callbackQueue  = callbackQueue
        self.main           = main
    }

    /**
     Run synchronously.
     */
    func run() -> ServiceCallResult<Payload> {
        let result: ServiceCallResult<Payload> = self.main()
        self.result = result
        return result
    }

    /**
     Run in background.

     - seealso: `ServiceCall.operationQueue`
     */
    func run(completion: @escaping Callback) {
        self.operationQueue.addOperation {
            let result: ServiceCallResult<Payload> = self.main()
            self.result = result
            self.callbackQueue.addOperation {
                completion(result)
            }
        }
    }

}


/**
 Wrapper over service method. Might be called only asynchronously.
 */
class CancelableServiceCall<Payload> {

    /**
     Signature for closure, which wraps service method logic.
     */
    typealias Main = (_ this: CancelableServiceCall<Payload>, _ callback: @escaping Callback) -> ()

    /**
     Completion callback signature.
     */
    typealias Callback = (_ result: ServiceCallResult<Payload>) -> ()

    /**
     Cancel closure signature.
     */
    typealias Cancel = () -> ()

    /**
     Background queue, where wrapped service logic will be performed.
     */
    let operationQueue: OperationQueue

    /**
     Completion callback queue.
     */
    let callbackQueue: OperationQueue

    /**
     Closure, which wraps service method logic.
     */
    let main: Main

    /**
     ServiceCall cancel closure.
     */
    var cancelClosure: Cancel?

    /**
     Result.
     */
    var result: ServiceCallResult<Payload>?

    /**
     Initializer.

     - Parameters:
     - operationQueue: background queue, where wrapped service logic will be performed
     - callbackQueue: completion callback queue
     - main: closure, which wraps service method logic.
     */
    init(
        operationQueue: OperationQueue,
        callbackQueue: OperationQueue,
        main: @escaping Main
    ) {
        self.operationQueue = operationQueue
        self.callbackQueue  = callbackQueue
        self.main           = main
    }

    /**
     Run in background.

     - seealso: `ServiceCall.operationQueue`
     */
    func run(completion: @escaping Callback) {
        self.operationQueue.addOperation {
            self.main(self) { (result: ServiceCallResult<Payload>) -> () in
                self.result = result
                self.callbackQueue.addOperation {
                    completion(result)
                }
            }
        }
    }

    /**
     Cancel ServiceCall.
     */
    func cancel() -> Bool {
        defer {
            cancelClosure?()
        }
        return nil != cancelClosure
    }

}


/**
 Basic service.
 */
class Service {

    /**
     Background working queue.
     */
    let operationQueue: OperationQueue

    /**
     Main queue for callbacks.
     */
    let completionQueue: OperationQueue

    /**
     Initializer.
     */
    init(
        operationQueue:  OperationQueue = OperationQueue(),
        completionQueue: OperationQueue = OperationQueue.main
    ) {
        self.operationQueue = operationQueue
        self.completionQueue = completionQueue
    }

    /**
     Assemble a sync/async call object.
     */
    func createCall<Payload>(main: @escaping ServiceCall<Payload>.Main) -> ServiceCall<Payload> {
        return ServiceCall(
            operationQueue: self.operationQueue,
            callbackQueue: self.completionQueue,
            main: main
        )
    }

    /**
     Assemble an async call object.
     */
    func createCancelableCall<Payload>(main: @escaping CancelableServiceCall<Payload>.Main) -> CancelableServiceCall<Payload> {
        return CancelableServiceCall(
            operationQueue: self.operationQueue,
            callbackQueue: self.completionQueue,
            main: main
        )
    }

}


/**
 Basic web service.
 */
class WebService: Service {

    /**
     Web service root.
     */
    let baseURL: URL

    /**
     Default request headers.
     */
    let headers: [String: String]

    /**
     Request interceptors for all requests.
     */
    let requestInterceptors: [HTTPRequestInterceptor]

    /**
     Response interceptors for all requests.
     */
    let responseInterceptors: [HTTPResponseInterceptor]

    /**
     Base request.
     */
    var baseRequest: HTTPRequest {
        return HTTPRequest(
            endpoint: baseURL.absoluteString,
            headers: headers,
            requestInterceptors: requestInterceptors,
            responseInterceptors: responseInterceptors
        )
    }

    /**
     Transport for requests.
     */
    let transport: HTTPTransport

    /**
     Empty JSON parameters.
     */
    var jsonParameters: HTTPRequestParameters {
        return HTTPRequestParameters(parameters: [:], encoding: HTTPRequestParameters.Encoding.json)
    }

    /**
     Empty URL parameters.
     */
    var urlParameters: HTTPRequestParameters {
        return HTTPRequestParameters(parameters: [:], encoding: HTTPRequestParameters.Encoding.url)
    }

    /**
     Empty property list parameters.
     */
    var plistParameters: HTTPRequestParameters {
        return HTTPRequestParameters(parameters: [:], encoding: HTTPRequestParameters.Encoding.propertyList)
    }

    /**
     Initializer.
     */
    init(
        operationQueue:         OperationQueue = OperationQueue(),
        completionQueue:        OperationQueue = OperationQueue.main,
        baseURL:                URL,
        transport:              HTTPTransport,
        requestInterceptors:    [HTTPRequestInterceptor]  = [],
        responseInterceptors:   [HTTPResponseInterceptor] = [],
        headers:                [String: String]          = [:]
    ) {
        self.baseURL        = baseURL
        self.transport      = transport
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.headers = headers
        super.init(operationQueue: operationQueue, completionQueue: completionQueue)
    }

    /**
     Allowing to fill HTTPRequestParameters with optional values.
     */
    func fillHTTPRequestParameters(
        _ httpRequestParameters: HTTPRequestParameters,
        with parameters: [String: Any?]
    ) -> HTTPRequestParameters {
        parameters.forEach { (parameter: (name: String, value: Any?)) in
            if let value: Any = parameter.value {
                httpRequestParameters[parameter.name] = value
            }
        }
        return httpRequestParameters
    }

    /**
     Choose parser for request.
     */
    func objectParser<Model: Decodable>(forURL url: String) -> ObjectParser<Model> {
        return ObjectParser<Model>()
    }

}


"""
