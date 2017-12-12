DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
cd "$DIR"

swift run ServiceAutograph -input_model Sources/Sandbox/Model -input_service Sources/Sandbox/Service -output Sources/Sandbox/GEN -verbose -write_parser
