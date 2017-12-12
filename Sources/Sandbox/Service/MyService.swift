import Foundation

/**
 Service serving Person objects.
 
 @service PersonServiceGen
 */
protocol PersonService {
    
    /**
     Get all people.
     */
    func get() -> ServiceCall<[Person]>
    
    /**
     Get single `Person`.
     
     @url /{id}
     */
    func get(
        personId id: Int // @url
    ) -> ServiceCall<Person>
    
    /**
     Register new `Person` with first name and last name.
     
     @post
     */
    func register(
        firstName: String, // @json first_name
        lastName: String   // @json last_name
    ) -> CancelableServiceCall<Void>
    
    /**
     Authorize.
     
     @put
     */
    func auth(
        token: String // @header X-Auth-Header
    ) -> ServiceCall<String>
    
}
