#!/usr/bin/env bash
#Cleanup:

for i in services/*; do
  service_name=`basename $i .yaml`
  echo $service_name
  gcloud alpha run services delete $service_name  --platform gke --cluster cluster-2 --cluster-location us-central1-c --namespace cloud-run-sandbox -q
done

kubectl delete -f redis.yaml -n cloud-run-sandbox
kubectl delete ns cloud-run-sandbox