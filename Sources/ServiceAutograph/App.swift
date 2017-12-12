//
// Project «ServiceAutograph»
// Created by Jeorge Taflanidi
//


import Foundation
import Autograph
import Synopsis


class App: AutographApplication {
    override func printHelp() {
        super.printHelp()
        print("""
        -input_model
        Input folder with model source files.
        If not set, current working directory is used as an input folder.

        -input_service
        Input folder with service protocols.
        If not set, current working directory is used as an input folder.

        -output
        Where to put generated files.
        If not set, current working directory is used as an input folder.

        -write_parser
        Generate object parser.


        """)
    }
    
    override func provideInputFoldersList(fromParameters parameters: ExecutionParameters) throws -> [String] {
        let input_model: String = parameters["-input_model"] ?? ""
        let input_service: String = parameters["-input_service"] ?? ""
        
        if input_model == input_service {
            return [input_model]
        }
        
        return [input_model, input_service]
    }
    
    override func compose(forSynopsis synopsis: Synopsis, parameters: ExecutionParameters) throws -> [Implementation] {
        let output: String = parameters["-output"] ?? "."
        
        var implementations: [Implementation] = []
        
        if nil != parameters["-write_parser"] {
            implementations.append(composeObjectParser(forSynopsis: synopsis, output: output))
        }
        
        implementations += try ServiceComposer.composeServices(forSynopsis: synopsis, output: output)
        
        return implementations
    }
    
    func composeObjectParser(forSynopsis synopsis: Synopsis, output: String) -> Implementation {
        var models: [Model] = []
        
        synopsis.classes
            .filter { $0.inheritesDecodable }
            .forEach { models.append(Model(name: $0.name, properties: $0.properties)) }
        
        synopsis.structures
            .filter { $0.inheritesDecodable }
            .forEach { models.append(Model(name: $0.name, properties: $0.properties)) }
        
        let sourceCode = objectParser + composeDecodableExtensions(forModels: models)
        
        return Implementation(
            filePath: output + "/ObjectParser.swift",
            sourceCode: sourceCode
        )
    }
    
    func composeDecodableExtensions(forModels models: [Model]) -> String {
        return models.reduce("\n") { (result: String, model: Model) -> String in
            let jsonKeys: [(String, String)] =
                model.properties
                    .filter { $0.hasJsonKey }
                    .map {
                        let jsonKey: String = $0.jsonKey ?? $0.name
                        return ($0.name, jsonKey)
                    }
            
            let cases: String
            if jsonKeys.isEmpty {
                cases = ""
            } else {
                cases = jsonKeys.reduce("\n") { (result: String, pair: (String, String)) -> String in
                    if jsonKeys.last! == pair {
                        return result + "        case \(pair.0) = \"\(pair.1)\""
                    }
                    return result + "        case \(pair.0) = \"\(pair.1)\"\n"
                }
            }
            
            return result + """
            extension \(model.name) {
                enum CodingKeys: String, CodingKey {\(cases)
                }
            }
            
            """ + (models.last == model ? "" : "\n")
        }
    }
    
    private let objectParser = """
    import Foundation

    class ObjectParser<Model: Decodable> {
        let decoder = JSONDecoder()
        var logErrors: Bool = false
        
        func parse(any: Any?) -> [Model] {
            if let data: Data = any as? Data {
                return parse(data: data)
            }
            
            if let dictionary: [String: Any] = any as? [String: Any] {
                return parse(dictionary: dictionary)
            }
            
            if let array: [Any] = any as? [Any] {
                return parse(array: array)
            }
            
            return []
        }
        
        func parse(data: Data) -> [Model] {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return parse(any: jsonObject)
            } catch {
                return []
            }
        }
        
        func parse(dictionary: [String: Any]) -> [Model] {
            return dictionary.keys.reduce(decode(dictionary: dictionary)) { $0 + parse(any: dictionary[$1]) }
        }
        
        func parse(array: [Any]) -> [Model] {
            return array.flatMap { parse(any: $0) }
        }
        
        func decode(dictionary: [String: Any]) -> [Model] {
            do {
                let dictionaryData: Data = try JSONSerialization.data(withJSONObject: dictionary)
                return try [decoder.decode(Model.self, from: dictionaryData)]
            } catch let error as DecodingError {
                log(error: error, dictionary: dictionary)
                return []
            } catch let error {
                if logErrors { print(error) }
                return []
            }
        }
        
        func log(error: DecodingError, dictionary: [String: Any]) {
            guard logErrors else { return }
            log(dictionary: dictionary)
            switch error {
                case .dataCorrupted(let context):    log(context: context)
                case .keyNotFound(_, let context):   log(context: context)
                case .typeMismatch(_, let context):  log(context: context)
                case .valueNotFound(_, let context): log(context: context)
            }
        }
        
        func log(context: DecodingError.Context) {
            guard logErrors else { return }
            print(context.debugDescription)
        }
        
        private func log(dictionary: [String: Any]) {
            do {
                let data = try JSONSerialization.data(withJSONObject: dictionary)
                if let string = String(data: data, encoding: String.Encoding.utf8) {
                    print(string)
                }
            } catch {
                return
            }
        }
    }

    """
}
