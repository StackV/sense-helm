#!/bin/bash
usage() {
    echo "Secret creation script: create-docker-secret.sh [-u username] [-p password] [-e email] [-f force deletion]" >&2
    exit 1
}

while getopts 'fu:p:e:' OPTION; do
    case "$OPTION" in
    f)
        force=true
        ;;
    u)
        username="$OPTARG"
        ;;
    p)
        password="$OPTARG"
        ;;
    e)
        email="$OPTARG"
        ;;
    ?)
        usage
        ;;
    esac
done

if [ ! -z ${force} ]; then
    echo "Deleting previous regcred... (if exists)"
    kubectl delete secret regcred
fi

if [ -z ${username+x} ] || [ -z ${password+x} ] || [ -z ${email+x} ]; then
    usage
else
    kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ \
        --docker-username=$username \
        --docker-password=$password \
        --docker-email=$email
fi
