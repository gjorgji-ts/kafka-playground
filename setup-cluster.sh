#!/bin/bash
set -e

echo "Creating Kind cluster..."
kind create cluster --config kind/kind-config.yaml

echo "Cluster created. Installing Strimzi Kafka Operator..."
kubectl create namespace kafka
kubectl config set-context --current --namespace=kafka
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm install strimzi-operator strimzi/strimzi-kafka-operator \
  -n kafka \
  --set resources.limits.memory=1024Mi \
  --set resources.requests.memory=512Mi

echo "Strimzi Kafka Operator installed. Wait for it to be ready..."
