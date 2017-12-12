import Foundation

/**
 A human being.
 */
struct Person: Decodable {
    /**
     First name.
     
     @json first_name
     */
    let firstName: String
    
    /**
     Last name.
     
     @json last_name
     */
    let lastName: String?
    
    /**
     Passport.
     
     @json
     */
    let passport: Passport?
}
