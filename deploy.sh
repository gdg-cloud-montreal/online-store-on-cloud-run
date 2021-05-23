#!/usr/bin/env bash

kubectl create ns cloud-run-sandbox
kubectl apply -f redis.yaml -n cloud-run-sandbox
sleep 10

for i in services/*; do
  service_name=`basename $i .yaml`
  echo $service_nameon  
  gcloud alpha run services replace $i  --platform gke --cluster cluster-1 --cluster-location us-central1-c --namespace cloud-run-sandbox
done