#!/usr/bin/env bash

export NAMESPACE=cloud-run-sandbox
export REVISION=$(kubectl get deploy -n istio-system -l app=istiod -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')

kubectl create ns $NAMESPACE

kubectl label namespace $NAMESPACE istio-injection- istio.io/rev=$REVISION --overwrite

kubectl apply -f redis.yaml -n $NAMESPACE
kubectl apply -f sa.yaml -n $NAMESPACE
# kubectl apply -f services/ -n $NAMESPACE
sleep 10

for i in services/*; do
  service_name=`basename $i .yaml`
  echo $service_nameon
  gcloud run services replace $i  --platform gke --cluster asm-crfa-cluster --cluster-location us-central1-b --namespace $NAMESPACE
done