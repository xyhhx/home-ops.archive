tf := terraform -chdir=terraform

init:
	$(tf) init
	poetry install

tf:
	$(tf) apply

generate-talos-configs: TALOS_CLUSTER_NAME
	talosctl gen secrets -o secrets/talos/secrets.yaml

	printf "cluster:\
		inlineManifests:\
			- name: cilium\
				contents: |\
	" >"$cilium_patchfile" &&\
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
			--set=cgroup.hostRoot=/sys/fs/cgroup | sed 's/^\(.*\)/        \1/g' > generated/cilium.yaml

	talosctl gen config $$TALOS_CLUSTER_NAME https://%s:6443 \
		--with-docs=false \
		--with-examples=false \
		--with-secrets secrets/talos/secrets.yaml \
		--config-patch @talos/patches/all.yaml \
		--config-patch-control-plane @talos/patches/controlplane.yaml \
		--config-patch-control-plane @generated/cilium.yaml \
		--config-patch-worker @talos/patches/worker.yaml \
		--output secrets/talos

down:
	gum confirm "This will delete your infra and configurations. Are you sure?" && \
	$(tf) destroy && \
	rm -rf secrets/talos/talosconfig.yaml secrets/kubeconfig.yaml

bootstrap-flux:
	$(MAKE) flux-crds
	sops -d secrets/bootstrap/sops-age.sops.yaml | kubectl apply -f -
	sops -d secrets/bootstrap/home-ops-deploy-key.sops.yaml | kubectl apply -f -
	sops -d secrets/bootstrap/home-ops-secrets-deploy-key.sops.yaml | kubectl apply -f -
	kubectl apply -f kubernetes/flux/vars/global-vars.yaml
	kubectl apply --server-side -k kubernetes/flux/system

# helpers:

flux-crds:
	kubectl apply --server-side -k kubernetes/bootstrap

flux-down:
	kubectl delete -k kubernetes/workloads
	flux uninstall

destroy-cilium:
	gum confirm "This will delete all shutdown cilium pods. Are you sure?" &&
	kubectl -n kube-system delete pods "$(kubectl get pods -n kube-system | grep cilium | grep Shutdown | grep 0/1 | awk '{print  $1}' | tr '\n' ' ')"
