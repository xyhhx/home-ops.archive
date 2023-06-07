#!/bin/bash

gum confirm "This will delete all shutdown cilium pods. Are you sure?" &&
  kubectl -n kube-system delete pods "$(kubectl get pods -n kube-system | grep cilium | grep Shutdown | grep 0/1 | awk '{print  $1}' | tr '\n' ' ')"
