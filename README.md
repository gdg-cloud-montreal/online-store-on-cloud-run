# cloud run sandbox

## CRFA Overview

Cloud Run for Anthos let's you leverage serverless containers on top of Kubernetes. CRFA provides you a Google-managed and supported Knative developer platform.

**Benefits Knative vs Kubernetes:**

- Simplify development complexity
- Operational flexibility of Kubernetes
- Serverless anywhere (scale to 0)

**Generations of Cloud Run for Anthos (CRFA):**

- CRFA v1 - First generation of Cloud Run for Anthos that was running Knative with Slim version of Istio is currently deprecated.
- CRFA v2 - Second generation of Cloud Run for Anthos running latest OSS Knative with GCP integrations and provides following benefits: 
    * `Anthos fleets` enable you to manage and upgrade your Cloud Run for Anthos installation independently of the other Anthos components.
    * Use of decoupled version of Anthos Service Mesh (ASM). 
    * Cloud Run for Anthos installation is always up-to-date as it run via managed `appdevexperience-operator` that runs in your cluster automatically rolls out the latest version of Cloud Run for Anthos.

See [Reference 1](https://cloud.google.com/anthos/run/docs/install#newandchanged) for other improvements. 


## CRFA Installation Overview

Cloud Run for Anthos require following steps:

- Setup GKE Cluster
- Register GKE Cluster to Anthos Hub
- Enable Anthos Service Mesh (ASM) with In-cluster control plane
- Enable CRFA

### Deploy GKE Cluster


**Step 1:** Create a cluster with the bellow command

Make sure to replace with your student LDAP and email

```
export EMAIL_ADDRESS=<email>
export STUDENT_LDAP=<STUDENT_LDAP>
export PROJECT_ID=<gcloud config get-value project>
```


```
export CLUSTER_NAME=$STUDENT_LDAP-cluster
export CLUSTER_LOCATION=us-central1-b
export HUB_PROJECT_ID=$PROJECT_ID
export MEMBERSHIP_NAME=gcp-$CLUSTER_NAME
gcloud config set project ${PROJECT_ID}
gcloud config set compute/zone ${CLUSTER_LOCATION}
```


First, make sure the proper APIs are enabled. Run the following command to enable the Container Registry API:

```
gcloud services enable container.googleapis.com \
                       anthos.googleapis.com \
                       containerregistry.googleapis.com \
                       artifactregistry.googleapis.com \
                       cloudbuild.googleapis.com \
                       gkeconnect.googleapis.com \
                       gkehub.googleapis.com \
                       cloudresourcemanager.googleapis.com \
                       iam.googleapis.com
```
Now you are ready to create a cluster!

```
gcloud container clusters create $CLUSTER_NAME  \
    --zone us-central1-b \
    --machine-type e2-standard-4 \
    --release-channel regular \
    --num-nodes 4 \
    --workload-pool=$PROJECT_ID.svc.id.goog \
    --addons=HttpLoadBalancing,NetworkPolicy \
    --monitoring=SYSTEM \
    --logging=SYSTEM,WORKLOAD \
    --enable-network-policy \
    --enable-ip-alias
```


!!! note
    GKE cluster has been deployed according to requirements for use with:

    * [Anthos Service Mesh (ASM)](https://cloud.google.com/service-mesh/docs/scripted-install/gke-asm-onboard-1-7#requirements) 
    * [CloudRun for Anthos (CRFA) ](https://cloud.google.com/run/docs/gke/setup#prerequisites)


### Register GKE Cluster to Anthos Hub¶


This module provides steps of how to register your Kubernetes clusters to a Google Cloud [fleet](https://cloud.google.com/anthos/multicluster-management/fleets).


**Step 1:** Registering a cluster using Workload Identity

```
gcloud container hub memberships register $MEMBERSHIP_NAME \
   --gke-cluster=$CLUSTER_LOCATION/$CLUSTER_NAME \
   --enable-workload-identity
```

**Step 2:** Inspect a cluster's registration status with `gcloud`


```
gcloud container hub memberships list
```
(Output)

```
NAME                EXTERNAL_ID
gcp-$CLUSTER_NAME  1f9d5805-a7d9-46a3-a5a4-526e137b9cff
```


### Deploy ASM with In-cluster control plane

*Note:* The Google-managed control plane is currently not fully supported by Cloud Run for Anthos.

#### Install ASM  core compoments

**Step 1:** Update the `gcloud` components and Authenticate with the Cloud SDK:

```
gcloud components update
gcloud auth login
```

**Step 2:** Your project must have the Service Mesh Feature enabled:

```
gcloud beta container hub mesh enable
```


**Step 3:**  Download the version of the script that installs Anthos Service Mesh 1.12 to the current working directory:

```
curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.13 > asmcli
chmod +x asmcli
```


Step 4: Get cluster credentials:



```
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone $CLUSTER_LOCATION \
    --project $PROJECT_ID
```


Default ASM Deployment:

```
./asmcli install \
  --project_id $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $CLUSTER_LOCATION \
  --fleet_id $PROJECT_ID \
  --output_dir $CLUSTER_NAME \
  --enable_all \
  --ca mesh_ca
```


ASM Deployment Istio Container Network Interface (Istio-CNI)
```
./asmcli install \
  --project_id $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $CLUSTER_LOCATION \
  --fleet_id $PROJECT_ID \
  --output_dir $CLUSTER_NAME \
  --enable_all \
  --option cni-gcp \
  --ca mesh_ca
```


!!! note
    If using a single-project, the FLEET_PROJECT_ID is the same as PROJECT_ID, the fleet host project and the cluster project are the same. In more complex configurations like multi-project, we recommend using a separate fleet host project.

!!! note
    ASM configuraiton may take a while the script will do following steps:
    * Enable required APIs
    * Configure required IAM roles
    * Enabling Workload Identity (if has not been enabled prior)
    * Create namespace `namespace/istio-system` on you cluster
    * Installing ASM control plane (istiod, ingress gateway)

(Output)

```
asmcli: Successfully installed ASM.
```


Verify components installed in `istio-system`

```
kubectl get deploy -n istio-system
```


!!! result
    `istiod` and `istio-ingressgateway` deployed in `istio-system` if you have Non-Managed istio
    Nothing will be observed if you use Google Managed istio
    

#### Deploy a public Ingress Gateway

1. Define required varaibles:

```
export GATEWAY_NAMESPACE=asm-ingress
export REVISION=$(kubectl get deploy -n istio-system \
    -l app=istiod \
    -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')
```


2. Create a namespace for the gateway

```
kubectl create namespace $GATEWAY_NAMESPACE
```

3. Enable auto-injection on the gateway by applying a revision label on the gateway namespace 

```
kubectl label namespace $GATEWAY_NAMESPACE istio-injection- istio.io/rev=$REVISION --overwrite
```

4. If you installed Anthos Service Mesh using asmcli, change to the directory that you specified in --output_dir


```
cd $CLUSTER_NAME
```

```
kubectl apply -n $GATEWAY_NAMESPACE -f samples/gateways/istio-ingressgateway
```

```
kubectl get pod,service -n $GATEWAY_NAMESPACE
```


### Customer Deploy Cloud Run for Anthos CRFA

Enable Cloud Run for Anthos in your Anthos fleet:


```
export PROJECT_ID=$(gcloud config get-value project)
gcloud container hub cloudrun enable --project=$PROJECT_ID
```


```
export INGRESSNAMESPACE=asm-ingress
export INGRESSNAME=istio-ingressgateway
export INGRESLABEL='app: istio-ingressgateway'

cat <<EOF > cloudrun.yaml
apiVersion: operator.run.cloud.google.com/v1alpha1
kind: CloudRun
metadata:
  name: cloud-run
spec:
  serving:
    ingressService:
      name: ${INGRESSNAME}
      namespace: ${INGRESSNAMESPACE}
      labels:
        ${INGRESLABEL}
EOF
```

```
gcloud container hub cloudrun apply \
    --gke-cluster $CLUSTER_LOCATION/$CLUSTER_NAME \
    --config=cloudrun.yaml
```

### Deploy Cloud Run for Anthos CRFA

Enable Cloud Run for Anthos in your Anthos fleet:

```
export PROJECT_ID=$(gcloud config get-value project)
gcloud container hub cloudrun enable --project=$PROJECT_ID
```


```
gcloud container hub cloudrun apply --gke-cluster=$CLUSTER_LOCATION/$CLUSTER_NAME
```



### Install `online-store-on-cloud-run` app

Let's install our microservices app with mTLS in permissive mode:

**Step 1:** Run Deploy script:


```
export ELBIP=<GW IP>
```

```
./deploy.sh
```


**Step 2:** Test the app:

```
http://frontend.cloud-run-sandbox.kuberun.$ELBIP6.nip.io/
```


**Result:** CRFA v2 works with `PERMISSIVE` mode in ASM!

### Enable  Istio mTLS feature for CRFA

Now let's test CRFA with mTLS in STRICT mode:

**Step 1.** Enable sidecar container on `knative-serving` system namespace.

```
export asmRevision=$(kubectl get deploy -n istio-system \
    -l app=istiod \
    -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')
```

```
kubectl label namespace knative-serving istio-injection- istio.io/rev=$asmRevision --overwrite
```

**Step 2.**  Set `PeerAuthentication` to `PERMISSIVE` on knative-serving system namespace by creating a YAML file using the following template:


```
cat <<EOF > knative-serving-permissive.yaml
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "knative-serving"
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

**Step 3.** Apply the YAML file by running the command:

```
kubectl apply -f knative-serving-permissive.yaml
```

**Step 4.** Restart Pods in "knative-serving" namespace with sidecar injected



### Enable mTLS Strict on `online-store-on-cloud-run` app

**Step 1.** Set `PeerAuthentication` on `cloud-run-sandbox` namespace as STRICT:

```
kubectl apply -f authn.yaml
```

**Step 2:** Test the app:

```
http://frontend.cloud-run-sandbox.kuberun.$ELBIP6.nip.io/
```


**Result:** Nothing works


### Cleanup


```
gcloud container hub memberships unregister $MEMBERSHIP_NAME \
   --gke-cluster=$CLUSTER_LOCATION/$CLUSTER_NAME
```


```
gcloud container clusters delete $CLUSTER_NAME
```

