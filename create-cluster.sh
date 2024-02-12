# for tesla-t4
#gcloud container clusters create llama2-inference-cluster --num-nodes=1 --min-nodes=1 --max-nodes=3    --zone=us-west1-b     --accelerator="type=nvidia-tesla-t4,count=2,gpu-driver-version=latest"  --machine-type="n1-standard-8"  --enable-private-nodes --master-ipv4-cidr 172.16.0.32/28  --enable-ip-alias --scopes="gke-default,storage-rw"

#tesla-l4:
#gcloud container clusters create llama2-inference-cluster --num-nodes=1 --min-nodes=1 --max-nodes=3  --zone=us-central1-a     --accelerator="type=nvidia-l4,count=2,gpu-driver-version=default"  --machine-type="g2-standard-24" --enable-ip-alias --scopes="gke-default,storage-rw"

# for L4 and spot private cluster
export PROJECT_ID=<your-project-id>
export REGION=us-central1
export ZONE_1=${REGION}-a # You may want to change the zone letter based on the region you selected above
export ZONE_2=${REGION}-b # You may want to change the zone letter based on the region you selected above
export CLUSTER_NAME=vllm-serving-cluster
export NAMESPACE=vllm
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE_1"

gcloud container clusters create $CLUSTER_NAME --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-b \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  --cluster-version 1.27.5-gke.200 \
  --num-nodes 1 --min-nodes 1 --max-nodes 3 \
  --ephemeral-storage-local-ssd=count=2 \
  --scopes="gke-default,storage-rw"

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
GCE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
for role in monitoring.metricWriter stackdriver.resourceMetadata.writer; do
  gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${GCE_SA} --role=roles/${role}
done


gcloud container node-pools create vllm-inference-pool --cluster \
vllm-inference --accelerator type=nvidia-l4,count=1,gpu-driver-version=latest   --machine-type g2-standard-8 \
--ephemeral-storage-local-ssd=count=1   --enable-autoscaling --enable-image-streaming   --num-nodes=0 --min-nodes=0 --max-nodes=3 \
--shielded-secure-boot   --shielded-integrity-monitoring --node-version=1.27.5-gke.200 --node-locations $ZONE_1,$ZONE_2 --region $REGION --spot

kubectl create ns vllm
kubectl create serviceaccount triton --namespace triton
gcloud iam service-accounts add-iam-policy-binding triton-server@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[triton/triton]"

kubectl annotate serviceaccount triton \
    --namespace triton \
    iam.gke.io/gcp-service-account=triton-server@${PROJECT_ID}.iam.gserviceaccount.com