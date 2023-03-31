tf := terraform -chdir=terraform
py := poetry run python

init:
	$(tf) init
	poetry install
	helm repo add cilium https://helm.cilium.io/
	helm repo add openebs-jiva https://openebs.github.io/jiva-operator
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

tf:
	$(tf) apply

talos-gen:
	$(py) ./scripts/talos.py gen

talos-apply:
	$(py) ./scripts/talos.py apply

talos-bootstrap:
	$(py) ./scripts/talos.py bootstrap

down:
	gum confirm "This will delete your infra and configurations. Are you sure?" && \
	$(tf) destroy && \
	rm -rf .talosconf kubeconfig
