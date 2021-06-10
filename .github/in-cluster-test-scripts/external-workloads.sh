#!/bin/sh

set -x
set -e

# Run connectivity test
cilium connectivity test --all-flows

# Retrieve Cilium status
cilium status
cilium clustermesh status
cilium clustermesh vm status

# Grab a sysdump and wait for it to be read.
cilium sysdump --output-filename cilium-sysdump-out
mkfifo /tmp/cilium-sysdump-out
cat cilium-sysdump-out.zip >> /tmp/cilium-sysdump-out
