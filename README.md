<header align="center">

# Homelab Ops

Getting the hang of this Kubernetes (and IaC) thing...

</header>

## Overview

This is a self-hosted [Kubernetes](https://kubernetes.io/) cluster, virtualized on [Proxmox](https://www.proxmox.com/en/) using [Talos Linux](https://talos.dev/), managed with [Flux](https://fluxcd.io/) and [Terraform](https://www.terraform.io/). Updates are managed with self-hosted [Renovate](https://renovatebot.com).

While I'll do my best to document my setup, this document may not be guaranteed to be up to date.

### Directory structure

The live directory structure looks like so:

```sh
📁 ─ generated                # Generated manifests for Talos

📁 ─ kubernetes
    📁 ─ bootstrap            # Contains kubernetes-specific manifests used during bootstrap

    📁 ─ flux
        📁 ─ repositories     # Repo manifests
        📁 ─ system           # System configuration
        📁 ─ vars             # Global vars

    📁 ─ workloads            # Workloads' manifests, organized by namespace
        📁 ─ cert-manager
        📁 ─ collabora
        📁 ─ default
        📁 ─ flux-system
        📁 ─ forgejo
        📁 ─ keycloak
        📁 ─ kube-system
        📁 ─ matrix
        📁 ─ media
        📁 ─ metallb
        📁 ─ monitoring
        📁 ─ nextcloud
        📁 ─ nfs-provisioner
        📁 ─ openebs

📁 ─ scripts                  # Helper scripts managing cluster

📁 ─ secrets
    📁 ─ bootstrap            # Bootstrap secrets
    📁 ─ namespaces           # Namespace-level workload secrets
        📁 ─ cert-manager
        📁 ─ collabora
        📁 ─ default
        📁 ─ dev-environment
        📁 ─ flux-system
        📁 ─ keycloak
        📁 ─ kube-system
        📁 ─ matrix
        📁 ─ media
        📁 ─ nextcloud
    📁 ─ scripts              # Helper scripts for secrets repo

📁 ─ talos                    # Talos-specific manifests
    📁 ─ manifests
    📁 ─ patches

📁 ─ terraform                # The terraform configs for provisioning nodes on proxmox
```

<details>
  <summary>Setup Instructions</summary>

### Existing Infrastructure / Requirements

- **OPNSense**
  - My network is managed by an OPNsense virtual machine
  - There should be a VLAN for the Talos nodes
  - That VLAN should have DHCP enabled
    - It is a good idea to separate the available addresses into those for physical nodes and those for pods running on them (which you will define in your metallb pool)
  - A user with enough access that they can retreive DHCP leases, for use with scripts
  - Port forwarding from your WAN to your decided IP
  - Unbound configured to point your domain to that IP on at least your Talos VLAN
- **External Storage**
  - There's an openmediavault VM on the Proxmox host
    - It has a NIC on the Talos cluster's VLAN
  - There are NFS shares for Talos
- **Proxmox configuration**
  - a **VM template to clone**, with a talos ISO in its cdrom drive
  - an **API Key for Proxmox**, as described in the Terraform provider's [docs](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs#creating-the-proxmox-user-and-role-for-terraform)
- **Git Repositories**
  - `home-ops`
    - This repo contains scripts and manifests necessary for bootstrapping and workloads (flux)
    - There are no secrets in this repo
  - `home-ops-secrets` / `home-ops/secrets`
    - This contains some SOPS encrypted secrets
    - Details in the [Secrets](#secrets) section
- I use [gum](https://github.com/charmbracelet/gum) in some places for pretty cli prompts (for now)
- [Poetry](https://python-poetry.org/) is used for Python scripts

## Bootsrapping the Cluster

### Provisioning Talos nodes on Proxmox

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

   > ℹ️ You can run `watch kubectl get pods --all-namespaces` to watch and see when your pods are ready

1. Install QEMU Guest Agent

   > ⚠️ This step requires manually stopping/starting nodes. My setup has 7 nodes, so that's the assumption here

   - Configure the cluster:

     ```sh
     kubectl create ns qemu-guest-agent
     kubectl create secret -n qemu-guest-agent generic talosconfig --from-file=config="$TALOSCONFIG"
     kubectl apply -f ./talos/manifests/qemu-guest-agent-sa.yaml
     ```

     At this point you will have failings pods equal to the total nodes you have. It's normal

   - Enable QEMU Guest Agent with Terraform

     ```sh
     terraform -chdir=terraform apply -var="qemu_guest_agent_enabled=1"
     ```

     Terraform will now try to update all nodes, but it won't be able to succeed until they're rebooted with the agent running.

   - Rebooting the nodes

     We'll shutdown all but 1 cp node, first.

     ```sh
     # Select all nodes except first cp node
     ips="$(poetry run talos ips --no-show-commands --type=workers |  tr '\n' ',' | sed 's/,$//'),$(poetry run talos ips --no-show-commands --type=control_plane | tail -n -2 | tr '\n' ',' | sed 's/,$//')"
     talosctl -n $ips shutdown
     ```

     Once they're off, just turn them back on in proxmox. They'll automatically boot, start the agent, reboot once more, and then satisfy Terraform.

     Finally, you can forcefully stop and restart the first cp node and it will also automatically reboot and configure itself.

     <details>
     <summary>ℹ️ To clear those failed Cilium pods:</summary>

     ```sh
     kubectl -n kube-system delete pods $(kubectl get pods -n kube-system | grep cilium | grep Shutdown | grep 0/1 | awk '{print  $1}' | tr '\n' ' ')
     ```

     </details>

1. Bootstrap Flux CRDs

   ```sh
   make flux
   ```

### Final Step(s)

- You will probably want to assign static mappings in OPNsense to ensure that Talos nodes keep their DHCP leases

  <h2 id="secrets">Secrets</h3>

The secrets repo contains predefined secrets necessary for bootstrapping the cluster and for workloads.

Since I use [Qubes](https://qubes-os.org), I've opted to split my secrets into those encrypted with GPG and those with age. In short, I can protect my private GPG key better by using Qubes [split GPG](https://www.qubes-os.org/doc/split-gpg/) and never leaving providing it to the cluster. This protects my repos' deploy keys and the cluster's age key.

### Usage

- The `home-ops-secrets` repo contains SOPS GPG encrypted Kubernetes Secret manifests containing the deploy keys for `home-ops`, `home-ops-secrest`, and an `age` key for Flux to use with SOPS
- The `make flux` command decrypts those (I configured SOPS to use `qubes-gpg-client-wrapper`) with GPG, then passes them to the cluster
- It then applies the Kustomize workloads in `kubernetes/flux`, which define the `home-ops` and `home-ops-secrets` repos as Sources, and spins up the workloads automatically

### Set up

(todo)

</details>

---

Some stuff I referenced while doing this:

- https://github.com/onedr0p/home-ops
- https://github.com/0dragosh/homelab
- https://www.talos.dev/v1.4/kubernetes-guides/configuration/replicated-local-storage-with-openebs-jiva/
- https://github.com/sleighzy/k3s-traefik-forward-auth-openid-connect
- https://github.com/jordemort/traefik-forward-auth

Thanks! 🙏

And of course a huge thank you to everyone on matrix who has helped me along the way!
