#!/usr/bin/env bash
#Cleanup:

export NAMESPACE=asmdashdemo
# for i in services/*; do
#   service_name=`basename $i .yaml`
#   echo $service_name
#   gcloud alpha run services delete $service_name  --platform gke --cluster crfa-cluster --cluster-location us-central1-b --namespace $NAMESPACE -q
# done

kubectl delete -f redis.yaml -n $NAMESPACE
kubectl delete -f services/ -n $NAMESPACE
kubectl delete ns $NAMESPACE