tf := terraform -chdir=terraform
py := poetry run python

init:
	$(tf) init
	poetry install

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
