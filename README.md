<header align="center">

# Homelab Ops

Getting the hang of this Kubernetes (and IaC) thing...

</header>

### Prerequirements

- **OPNSense** with a DHCP-enabled VLAN for nodes to use
    - You will need a user to log in with
- a **VM template in Proxmox to clone**, with a talos ISO in its cdrom drive
- an **API Key for Proxmox**, as described in the Terraform provider's [docs](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs#creating-the-proxmox-user-and-role-for-terraform)
- I use [gum](https://github.com/charmbracelet/gum) in some places for pretty cli prompts (for now)

## Installation

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


