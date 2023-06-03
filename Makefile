tf := terraform -chdir=terraform

init:
	$(tf) init
	poetry install
	helm repo add cilium https://helm.cilium.io/
	helm repo add openebs-jiva https://openebs.github.io/jiva-operator
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

tf:
	$(tf) apply

down:
	gum confirm "This will delete your infra and configurations. Are you sure?" && \
	$(tf) destroy && \
	rm -rf .talosconf kubeconfig

flux:
	kubectl apply --server-side --kustomize kubernetes/bootstrap
	sops -d secrets/home-ops-deploy-key.sops.yaml | kubectl apply -f -
	sops -d secrets/home-ops-secrets-deploy-key.sops.yaml | kubectl apply -f -
	kubectl apply --server-side --kustomize kubernetes/flux/config
