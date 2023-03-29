<center>

# Deploy Talos Linux on Proxmox

</center>

The goal of this project is to deploy Kubernetes on Proxmox using Talos automatically, on a network controlled by OPNsense.

### Installation

1. Set up vars. `.envrc` will contain your sensitive vars like credentials and tokens. `terraform/.auto.tfvars` will contain your terraform specific config stuff

```
cp .envrc.example .envrc
touch terraform/.auto.tfvars
```

2. Provision your infra with terraform:

```
make tf
```

3. Generate talos configs

```
make talos-gen
# Copy the command that it outputs
rm -rf .talosconf
# paste the command
make talos-gen # (again)
make talos-apply
```

4. Wait for one of the control plane nodes to say something about "please run talosctl bootstrap", then do:

```
make talos-bootstrap
```

  - You can run `watch kubectl get nodes` to watch and see when your nodes are ready

5. Install Cilium

```
helm install cilium cilium/cilium --version 1.11.2 --namespace kube-system --set ipam.mode=kubernetes --set kubeProxyReplacement=strict --set hostServices.enabled=true
```

6. You will need to go through the motions to install/configure storage with OpenEBS:

```
ips=$(poetry run python ./scripts/talos.py ips --no-show-commands --type=control_plane |  tr '\n' ',' | sed 's/,$//')
talosctl -n $ips  patch mc -p @./manifests/talos/patches/controlplane-patches.yaml
ips=$(poetry run python ./scripts/talos.py ips --no-show-commands --type=workers |  tr '\n' ',' | sed 's/,$//')
talosctl -n $ips  patch mc -p @./manifests/talos/patches/worker-patches.yaml

ips=$(poetry run python ./scripts/talos.py ips --no-show-commands --type=control_plane |  tr '\n' ',' | sed 's/,$//')
talosctl -n $ips upgrade  --image=ghcr.io/siderolabs/installer:v1.3.5
ips=$(poetry run python ./scripts/talos.py ips --no-show-commands --type=workers |  tr '\n' ',' | sed 's/,$//')
talosctl -n $ips upgrade  --image=ghcr.io/siderolabs/installer:v1.3.5

helm upgrade --install --create-namespace --namespace openebs --version 3.2.0 openebs-jiva openebs-jiva/jiva
kubectl apply -n openebs -f ./manifests/kubernetes/openebs/configmap.yaml
kubectl -n openebs patch daemonset openebs-jiva-csi-node --type=json --patch '[{"op": "add", "path": "/spec/template/spec/hostPID", "value": true}]'
kubectl patch sc openebs-jiva-csi-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

helm upgrade --install --create-namespace -n monitoring kube-prometheus-stack prometheus-community/kube-prometheus-stack
```


