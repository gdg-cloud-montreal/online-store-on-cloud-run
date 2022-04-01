#!/usr/bin/env bash

export NAMESPACE=asmdashdemo
export REVISION=asm-1125-0

kubectl create ns $NAMESPACE

kubectl label namespace $NAMESPACE istio-injection- istio.io/rev=$REVISION --overwrite

kubectl apply -f redis.yaml -n $NAMESPACE
kubectl apply -f services/ -n $NAMESPACE
# sleep 10

# for i in services/*; do
#   service_name=`basename $i .yaml`
#   echo $service_nameon
#   gcloud alpha run services replace $i  --platform gke --cluster crfa-cluster --cluster-location us-central1-b --namespace $NAMESPACE
# done
