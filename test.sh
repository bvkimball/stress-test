#!/bin/sh

SIZE=-1
OPERATION="undefined"
TAG="latest"

while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -t|--tag)
    TAG="$2"
    shift # past argument
    ;;
    -s|--size)
    SIZE="$2"
    shift # past argument
    ;;
    --default)
    DEFAULT=YES 
    ;;
    *)
    # unknown option
    OPERATION="$key"
    ;;
esac
shift # past argument or value
done

if [ ${#1} -gt 0 ]
then
    OPERATION="$1"
fi

createClusters() {
    echo "Creating new clusters..."
    gcloud container clusters create socket-stress-useast --num-nodes 1 --machine-type n1-standard-1 --zone us-east1-b
    gcloud container clusters create socket-stress-uswest --num-nodes 1 --machine-type n1-standard-1 --zone us-west1-b
    gcloud container clusters create socket-stress-europe --num-nodes 1 --machine-type n1-standard-1 --zone europe-west1-d
}

scalingClusters() {
    echo "Scaling cluster to $1"
    gcloud container clusters get-credentials socket-stress-useast -z us-east1-b
    gcloud container clusters resize socket-stress-useast --size $1 -z us-east1-b
    gcloud container clusters get-credentials socket-stress-uswest -z us-west1-b
    gcloud container clusters resize socket-stress-uswest --size $1 -z us-west1-b
    gcloud container clusters get-credentials socket-stress-europe -z europe-west1-d
    gcloud container clusters resize socket-stress-europe --size $1 -z europe-west1-d
}

deployDaemon() {
    echo "Running Daemons"
    gcloud container clusters get-credentials socket-stress-useast -z us-east1-b
    kubectl create -f ./deployment.yaml
    gcloud container clusters get-credentials socket-stress-uswest -z us-west1-b
    kubectl create -f ./deployment.yaml
    gcloud container clusters get-credentials socket-stress-europe -z europe-west1-d
    kubectl create -f ./deployment.yaml
}

cleanUp() {
    echo "Stopping Daemons"
    gcloud container clusters get-credentials socket-stress-useast -z us-east1-b
    kubectl delete -f ./deployment.yaml
    gcloud container clusters get-credentials socket-stress-uswest -z us-west1-b
    kubectl delete -f ./deployment.yaml
    gcloud container clusters get-credentials socket-stress-europe -z europe-west1-d
    kubectl delete -f ./deployment.yaml
}

exportReportFromFirebase() {
    echo "Generating report..."
    mkdir ./reports
    curl https://artillery-tests.firebaseio.com/stress-tests.json | jq 'keys' | jq '.[]' | tr -d \" | while read id ; do
        curl https://artillery-tests.firebaseio.com/stress-tests/${id}.json | jq '.' > ./reports/artillery_report_${id}.json
        artillery report ./reports/artillery_report_${id}.json
    done
}

buildImage() {
    echo "Building Docker Image..."
    docker build --no-cache -t bullhorn/socket-stress:${TAG} .
    ## Tag App
    docker tag bullhorn/socket-stress:${TAG} us.gcr.io/artillery-tests/socket-stress:${TAG}
    ## Push App to Google Container Registry
    gcloud docker -- push us.gcr.io/artillery-tests/socket-stress:${TAG}
}

main() {
    gcloud config set project artillery-tests

    if [ $OPERATION = 'init' ]
    then
        createClusters
    fi
    if [ $OPERATION = 'resize' ]
    then
        if [ $SIZE -ge 0 ]
        then
            scalingClusters ${SIZE}
        fi
    fi
    if [ $OPERATION = 'start' ]
    then
        deployDaemon
    fi
    if [ $OPERATION = 'stop' ]
    then
        cleanUp
        if [ $SIZE -eq 0 ]
        then
            scalingClusters ${SIZE}
        fi
    fi
    if [ $OPERATION = 'report' ]
    then
        exportReportFromFirebase
    fi
    if [ $OPERATION = 'build' ]
    then
        buildImage
    fi
    
}

main $ARGS
