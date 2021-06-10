#!/bin/sh

set -x
set -e

# Enable Relay
cilium hubble enable

# Wait for Cilium status to be ready
cilium status --wait

# Port forward Relay
cilium hubble port-forward&
sleep 10s

# Run connectivity test
cilium connectivity test --test '!/pod-to-local-nodeport' --all-flows

# Grab a sysdump and wait for it to be read.
cilium sysdump --output-filename cilium-sysdump-out
mkfifo /tmp/cilium-sysdump-out
cat cilium-sysdump-out.zip >> /tmp/cilium-sysdump-out
