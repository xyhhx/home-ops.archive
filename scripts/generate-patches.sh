#!/bin/bash

output_dir="generated"
cilium_patchfile="$output_dir/cilium.yaml"

mkdir "$output_dir" &&
  printf "cluster:
  inlineManifests:
    - name: cilium
      contents: |
" >"$cilium_patchfile" &&
  helm template \
    cilium \
    cilium/cilium \
    --version 1.13.0 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set=kubeProxyReplacement=disabled \
    --set=securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set=securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set=cgroup.autoMount.enabled=false \
    --set=cgroup.hostRoot=/sys/fs/cgroup | sed 's/^\(.*\)/        \1/g' >>"$cilium_patchfile" &&
  cp talos/patches/all.yaml talos/patches/controlplane.yaml talos/patches/worker.yaml "$output_dir"
