#!/bin/sh

readonly ARGS="$@"
readonly ARTILLERY_CONFIG="/usr/src/stress-test/app8-socket-stress.yaml"
readonly TMP_DIR="/usr/src/tmp"
readonly OUTPUT_DIRECTORY="/var/lib/logs"

storeConfig() {
    echo "Storing artillery configuration..."
    ## cat - > "$ARTILLERY_CONFIG"
}

runArtillery() {
    echo "Starting artillery..."
    cd /usr/src/stress-test
    artillery run app8-socket-stress.yaml
}

sendReportToFirebase() {
    files=$(find artillery_report_*.json)
    for file in $files
    do 
        curl -X POST https://artillery-tests.firebaseio.com/stress-tests.json -d @${file} --header "Content-Type: application/json"
    done
}

keepAlive() {
    tail -f /dev/null
}

main() {
    storeConfig
    runArtillery $@
    sendReportToFirebase
    keepAlive
}

main $ARGS

