#!/bin/bash
kubectl get pods -n vllm
kubectl apply -f vllm2-deploy.yaml -n vllm
kubectl get ingress -n vllm -o yaml
kubectl get svc -n vllm -o yaml
kubectl get deployment -n vllm
kubectl delete deployment vllm-server -n vllm
kubectl get pods -n vllm
gcloud container clusters resize vllm-serving-cluster --node-pool g2-standard-24 --num-nodes 0 --region us-central1
gcloud container clusters resize vllm-serving-cluster --node-pool default-pool --num-nodes 0 --region us-central1
