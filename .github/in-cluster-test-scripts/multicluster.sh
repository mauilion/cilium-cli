#!/bin/sh

set -x
set -e

# Create two FIFOs through which we'll pipe the sysdumps before the job terminates.
# NOTE: This MUST be the first step in the script.

# Set up contexts
CONTEXT1=$(kubectl config view | grep "${CLUSTER_NAME_1}" | head -1 | awk '{print $2}')
CONTEXT2=$(kubectl config view | grep "${CLUSTER_NAME_2}" | head -1 | awk '{print $2}')

# Install Cilium in cluster1
cilium install \
  --context "${CONTEXT1}" \
  --cluster-name "${CLUSTER_NAME_1}" \
  --cluster-id 1 \
  --config monitor-aggregation=none \
  --native-routing-cidr="${CLUSTER_CIDR_1}"

# Install Cilium in cluster2
cilium install \
  --context "${CONTEXT2}" \
  --cluster-name "${CLUSTER_NAME_2}" \
  --cluster-id 2 \
  --config monitor-aggregation=none \
  --native-routing-cidr="${CLUSTER_CIDR_2}" \
  --inherit-ca "${CONTEXT1}"

# Enable Relay
cilium --context "${CONTEXT1}" hubble enable
cilium --context "${CONTEXT2}" hubble enable --relay=false

# Wait for Cilium status to be ready
cilium --context "${CONTEXT1}" status --wait
cilium --context "${CONTEXT2}" status --wait

# Enable cluster mesh
cilium --context "${CONTEXT1}" clustermesh enable
cilium --context "${CONTEXT2}" clustermesh enable

# Wait for cluster mesh status to be ready
cilium --context "${CONTEXT1}" clustermesh status --wait
cilium --context "${CONTEXT2}" clustermesh status --wait

# Connect clusters
cilium --context "${CONTEXT1}" clustermesh connect --destination-context "${CONTEXT2}"

# Wait for cluster mesh status to be ready
cilium --context "${CONTEXT1}" clustermesh status --wait
cilium --context "${CONTEXT2}" clustermesh status --wait

# Port forward Relay
cilium --context "${CONTEXT1}" hubble port-forward&
sleep 10s

# Run connectivity test
cilium --context "${CONTEXT1}" connectivity test --multi-cluster "${CONTEXT2}" --test '!/pod-to-.*-nodeport' --all-flows

# Retrieve Cilium status
cilium --context "${CONTEXT1}" status
cilium --context "${CONTEXT1}" clustermesh status
cilium --context "${CONTEXT2}" status
cilium --context "${CONTEXT2}" clustermesh status

# Grab a sysdump of each cluster and wait for it to be read.
cilium --context "${CONTEXT1}" sysdump --output-filename cilium-sysdump-out-1
mkfifo /tmp/cilium-sysdump-out-1
cat cilium-sysdump-out-1.zip >> /tmp/cilium-sysdump-out-1
cilium --context "${CONTEXT2}" sysdump --output-filename cilium-sysdump-out-2
mkfifo /tmp/cilium-sysdump-out-2
cat cilium-sysdump-out-2.zip >> /tmp/cilium-sysdump-out-2
