<center>

# Homelab Ops

Getting the hang of this Kubernetes (and IaC) thing...

</center>

### Prerequirements

- **OPNSense** with a DHCP-enabled VLAN for nodes to use
    - You will need a user to log in with
- a **VM template in Proxmox to clone**, with a talos ISO in its cdrom drive
- an **API Key for Proxmox**, as described in the Terraform provider's [docs](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs#creating-the-proxmox-user-and-role-for-terraform)

### Installation

1. Set up vars. `.env` will contain your sensitive vars like credentials and tokens. `terraform/.auto.tfvars` will contain your terraform specific config stuff

    ```sh
    cp .env.example .env
    touch terraform/.auto.tfvars
    ```


    <details>
    <summary>
        ℹ️ Example .auto.tfvars
    </summary>

    ```
    bridge              = "vmbrX"
    pve_node            = "nodename"
    storage             = "zfsX"
    talos_template_name = "talos-node" # the name of the vm template with the talos iso in cdrom
    vlan_tag            = "69" # nice
    pve_tags            = "" # if any

    control_plane_nodes_count = 3
    control_plane_total_mem   = 12288
    worker_nodes_count        = 4
    workers_total_mem         = 53248
    ```
    </details>



1. Provision your infra with terraform:

    ```sh
    make tf
    ```

1. Prepare secrets and patches

    Generate the necessary patches using the packaged script

    ```sh
    ./scripts/generate-patches.sh
    ```

    Generate Talos secrets (or bring your own I guess)

    ```sh
    talosctl gen secrets -o talos/secrets.yaml
    ```

1. Generate and apply talos configs

    ```sh
    poetry run talos gen
    poetry run talos apply
    ```

1. Wait for one of the control plane nodes to say something about "please run talosctl bootstrap", then do:

    ```sh
    poetry run talos bootstrap
    ```

    Wait for all pods to succeed before continuing

    > ℹ️ You can run `watch kubectl get nodes` to watch and see when your nodes are ready



1. Install QEMU Guest Agent

    > ⚠️ This step requires manually stopping/starting nodes. If you don't have redundant nodes, your cluster will experience downtime (though only a few minutes)

    ```sh
    kubectl create ns qemu-guest-agent
    kubectl create secret -n qemu-guest-agent generic talosconfig --from-file=config="$TALOSCONFIG"
    kubectl apply -f ./talos/manifests/qemu-guest-agent-sa.yaml
    ```

    At this point you will have failings pods equal to the total nodes you have.

    ```sh
    terraform -chdir=terraform apply -var="qemu_guest_agent_enabled=1"
    ```

    Terraform will now try to update all nodes.

    ```sh
    # Workers
    ips=$(poetry run talos ips --no-show-commands --type=workers |  tr '\n' ',' | sed 's/,$//')
    talosctl -n $ips shutdown
    # Control Planes (Not 1st)
    ips=$(poetry run talos ips --no-show-commands --type=control_plane | tail -n -2 | tr '\n' ',' | sed 's/,$//')
    talosctl -n $ips shutdown
    # 1st Control Plane
    ips=$(poetry run talos ips --no-show-commands --type=control_plane | head -n 1 | tr '\n' ',' | sed 's/,$//')
    talosctl -n $ips shutdown
    ```

    Now manually start all your nodes' VMs. When they start, they will restart once and then Terraform will be satisfied. If it complains, you can rerun the `apply` command and it should just work.

1. Install MetalLB:

    ```sh
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
    # Wait for all pods to succeed

    kubectl apply -n metallb-system -f ./kubernetes/apps/metallb/nice-pool.yaml  -f ./kubernetes/apps/metallb/default-l2-advertisement.yaml
    # Wait for all pods to succeed
    ```


1. Install the Helm releases:

    > ℹ️ (To move to Flux)

    ```sh
    helm upgrade --install --create-namespace --namespace openebs --version 3.2.0 openebs-jiva openebs-jiva/jiva
    kubectl apply -n openebs -f ./kubernetes/apps/openebs/configmap.yaml
    kubectl -n openebs patch daemonset openebs-jiva-csi-node --type=json --patch '[{"op": "add", "path": "/spec/template/spec/hostPID", "value": true}]'
    ```
    ```sh
    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
    helm install -n nfs-provisioner --create-namespace nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner -f ./kubernetes/apps/nfs-subdir-external-provisioner/values.yaml
    ```
    ```sh
    helm upgrade --install --create-namespace -n monitoring kube-prometheus-stack prometheus-community/kube-prometheus-stack
    ```
    ```sh
    kubectl apply -f ./kubernetes/apps/traefik/deployment.yaml
    ```

