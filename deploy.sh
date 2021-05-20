#!/usr/bin/env bash

kubectl create ns cloud-run-sandbox
kubectl apply -f redis.yaml -n cloud-run-sandbox
sleep 10

for i in services/*; do
  service_name=`basename $i .yaml`
  echo $service_name
  gcloud alpha run services replace $i  --platform gke --cluster bee-dev-gke --cluster-location us-central1 --namespace cloud-run-sandbox
done