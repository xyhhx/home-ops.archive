tf := terraform -chdir=terraform

init:
	$(tf) init
	poetry install

tf:
	$(tf) apply

down:
	gum confirm "This will delete your infra and configurations. Are you sure?" && \
	$(tf) destroy && \
	rm -rf .talosconf kubeconfig

flux-only:
	kubectl apply --server-side --kustomize kubernetes/bootstrap

flux:
	kubectl apply --server-side --kustomize kubernetes/bootstrap
	sops -d secrets/bootstrap/sops-age.sops.yaml | kubectl apply -f -
	sops -d secrets/bootstrap/home-ops-deploy-key.sops.yaml | kubectl apply -f -
	sops -d secrets/bootstrap/home-ops-secrets-deploy-key.sops.yaml | kubectl apply -f -
	kubectl apply -f kubernetes/flux/vars/global-vars.yaml
	kubectl apply --server-side --kustomize kubernetes/flux/system

flux-down:
	kubectl delete --kustomize kubernetes/workloads
	flux uninstall

k8s-cilium:
	./scripts/delete-failed-cilium-pods.sh
