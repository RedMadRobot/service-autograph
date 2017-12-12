import Foundation

/**
 A human being passport.
 */
struct Passport: Decodable {
    /**
     Series.
     
     @json
     */
    let series: String
    
    /**
     Number.
     
     @json
     */
    let number: String
}
