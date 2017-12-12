# Service Autograph

Service and object parser generation utility based on [Autograph](https://github.com/RedMadRobot/autograph) and [Synopsis](https://github.com/RedMadRobot/synopsis) frameworks.

# Usage
## Prepare your sources

Mark your service protocols like this:

```swift
/**
 MANDATORY SERVICE ANNOTATION:
 @service PersonServiceGen
 
 YOU MAY OMIT THE EXPLICIT SERVICE NAME
 */
protocol PersonService {

    /**
     EACH SERVICE METHOD MUST RETURN ServiceCall<> OR CancelableServiceCall<>
     
     `GET` IS A DEFAULT HTTP METHOD.
     */
    func get() -> ServiceCall<[Person]>
    
    /**
     PROVIDE RELATIVE URL
     @url /{id}
     
     BASE URL IS INJECTED BY CONSTRUCTOR
     */
    func get(
        personId id: Int // MARK ARGUMENTS TO BE INSERTED INTO URL PLACEHOLDERS: @url
    ) -> ServiceCall<Person>
    
    /**
     SUPPORTED HTTP METHODS: get, post, put, patch, delete, head, options
     @post
     
     USE CancelableServiceCall<> WHEN CALL CANCELING OPTION IS REQUIRED
     
     KEEP IN MIND YOU CAN USE Void IN CASE YOU DON'T NEED SERVER RESPONSE TO BE PARSED
     */
    func register(
        firstName: String, // @json first_name
        lastName: String   // @json last_name
    ) -> CancelableServiceCall<Void>
    
    /**
     SUPPORTED ARGUMENT SERIALIZATION OPTIONS: json, query, plist, url, header
     
     ARGUMENT BODY NAME IS AN IMPLICIT ANNOTATION VALUE
     
     @put
     */
    func auth(
        token: String // @header X-Auth-Header
    ) -> ServiceCall<String>
    
}
```

**Service Autograph** will generate concrete implementations for each of your service protocols and also a supporting `Service.swift` file.

**Service Autograph** can also generate a generic `object parser` utility class for you, and also `Decodable` extensions for each of your models.
In order to do so, use corresponding `-write_parser` argument.

## Build executable

Run `spm_build.command` script in order to build from sources.

You'll find your `ServiceAutograph` executable in `./build/x86_64-apple-macosx10.10/release` folder or similar, depending on your OS.

## Add run script build phase to your project

Run `ServiceAutograph` executable before other build phases, so that new generated source code would be taken into the process.
The utility accepts next arguments:

* `-help` — print help, do not execute;
* `-verbose` — print additional debug information;
* `-write_parser` — turn on object parser generation;
* `-input_model [folder]` — path to the folder with your model classes and structures (used during parser generation);
* `-input_service [folder]` — path to the folder with your service protocols;
* `-output [folder]` — path to the folder, where to put generated files.

Your script may look like this:

```bash
SERVICE_AUTOGRAPH_PATH=Utilities/ServiceAutograph

if [ -f $SERVICE_AUTOGRAPH_PATH ]
then
    echo "ServiceAutograph executable found"
else
    osascript -e 'tell app "Xcode" to display dialog "Service generator executable not found in \nUtilities/ServiceAutograph" buttons {"OK"} with icon caution'
fi

$SERVICE_AUTOGRAPH_PATH \
    -write_parser \
    -input_model "$PROJECT_NAME/Classes/Model" \
    -input_service "$PROJECT_NAME/Classes/Service" \
    -output "./$PROJECT_NAME/Generated/Classes"
```

## Demo & running tests

Use `spm_resolve.command` to load all dependencies and `spm_generate_xcodeproj.command` to assemble an Xcode project file.
Also, ensure Xcode targets macOS.

Run `spm_run_sandbox.command` script for a demo — it builds and launches **Service Autograph** with `Sources/Sandbox` as a working directory.
