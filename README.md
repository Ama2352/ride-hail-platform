# ride-hail-platform (Repo 1 of 3)

> Infrastructure provisioning, Kubernetes bootstrap, and ArgoCD installation for the Ride-Hailing platform.

---

## 🔗 Related Repositories
- **ride-hail-platform** (Repo 1 - You are here)
- [ride-hail-services](https://github.com/ama2352/ride-hail-services) (Repo 2 - Application Source)
- [ride-hail-gitops](https://github.com/ama2352/ride-hail-gitops) (Repo 3 - K8s Manifests & App Config)

---

## 🏛️ Architecture Overview

This repository uses Vagrant and Ansible to create a local Multi-Node Kubernetes development cluster natively, establishing the foundation of the GitOps rollout. 

```text
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  ride-hail-platform │     │  ride-hail-services  │     │  ride-hail-gitops   │
│  >>> THIS REPO <<<  │     │      (Repo 2)        │     │      (Repo 3)       │
│                     │     │                      │     │                     │
│  Vagrant, Ansible,  │     │  Go source code,     │     │  K8s manifests,     │
│  K8s bootstrap,     │     │  Dockerfiles,        │     │  Helm values,       │
│  ArgoCD install     │     │  Jenkins & GitLab CI │     │  ArgoCD App defs    │
└─────────────────────┘     └──────────┬───────────┘     └──────────▲──────────┘
                                       │  git commit image tag      │
                                       └───────────────────────────►┘
                                              ArgoCD reconciles
```

---

## 🚀 Dual-CI Workflows

The platform seamlessly integrates with dual CI engines deployed externally or locally:

- **Jenkins Workflow:** Provided as a legacy path, where code changes trigger Jenkins pipelines that build and update `ride-hail-gitops`, triggering ArgoCD synchronization. 
- **GitLab CI Workflow:** Modern, native pipeline defining a `build->scan->push->gitops` lifecycle via GitLab runners, committing updates to `ride-hail-gitops`.

In both workflows, ArgoCD (installed by this platform) remains the sole authoritative engine handling Continuous Deployment (CD).

---

## ⚙️ Setup Guide (Fresh Environment)

### Prerequisites:
- Vagrant >= 2.3
- VMware Desktop + `vagrant-vmware-desktop` plugin
- ~12 GB free RAM on host

### Initialization:
1. Clone this repository.
2. Initialize the platform infrastructure:
   ```bash
   vagrant up
   ```
3. Once provisioning resolves, ArgoCD is natively bootstrapped and immediately begins resolving applications from `ride-hail-gitops`. You can access clusters natively:
   - **ArgoCD:** `https://192.168.242.10:30080`
   - **Grafana:** `http://192.168.242.11:30300`
   - **Jenkins:** `http://192.168.242.13:8080`
   
*(To reboot ArgoCD without tearing down VMs)*: Wait until vagrant resolves then use `vagrant provision k8s-master --provision-with argocd`.

---

## 🔐 Secret Workflow (One Secret File -> SealedSecret)

Each Kubernetes Secret is stored in its own source file under `.secrets/` and then sealed into `SealedSecret` for GitOps overlays.

Do not keep plain `kind: Secret` manifests inside `ride-hail-gitops` overlays for normal flow.

### Secret source files
- `.secrets/rsa-keys.ride-hailing-dev.secret.yaml`
- `.secrets/rsa-keys.ride-hailing-test.secret.yaml`
- `.secrets/rsa-keys.ride-hailing-prod.secret.yaml`
- `.secrets/ride-db-credentials.ride-hailing-dev.secret.yaml`
- `.secrets/ride-db-credentials.default.secret.yaml`

### Current overlay check
- SealedSecret already used:
   - `apps/dispatch/overlays/dev/sealed-secrets.yaml`
   - `apps/dispatch/overlays/test/sealed-secret-rsa-keys.yaml`
   - `apps/dispatch/overlays/prod/sealed-secret-rsa-keys.yaml`
   - `apps/user/overlays/dev/sealed-secrets.yaml`
- Template SealedSecret for ride DB credentials:
   - `apps/ride/overlays/dev/sealed-secret-ride-db-credentials.yaml`

### Prerequisites (inside `k8s-master` VM)
- Sealed Secrets controller is installed by ArgoCD in `kube-system`.
- Controller name used by this project: `sealed-secrets-controller`.
- Tools: `kubeseal`, `kubectl`.

### Install `kubeseal` first (required)

```bash
vagrant ssh k8s-master
cd /vagrant/.secrets
chmod +x ./install_kubeseal.sh
./install_kubeseal.sh
kubeseal --version
```

### Generate `private.pem` + `public.pem` for `rsa-keys`

```bash
vagrant ssh k8s-master
cd /vagrant/.keys
go run generate.go
```

### Build source Secret manifest from generated key pair

This avoids manual base64 editing and keeps each Secret in one source file.

```bash
vagrant ssh k8s-master

# dev
kubectl create secret generic rsa-keys \
   --namespace ride-hailing-dev \
   --from-file=private.pem=/vagrant/.keys/private.pem \
   --from-file=public.pem=/vagrant/.keys/public.pem \
   --dry-run=client -o yaml \
   > /vagrant/.secrets/rsa-keys.ride-hailing-dev.secret.yaml

# test
kubectl create secret generic rsa-keys \
   --namespace ride-hailing-test \
   --from-file=private.pem=/vagrant/.keys/private.pem \
   --from-file=public.pem=/vagrant/.keys/public.pem \
   --dry-run=client -o yaml \
   > /vagrant/.secrets/rsa-keys.ride-hailing-test.secret.yaml

# prod
kubectl create secret generic rsa-keys \
   --namespace ride-hailing-prod \
   --from-file=private.pem=/vagrant/.keys/private.pem \
   --from-file=public.pem=/vagrant/.keys/public.pem \
   --dry-run=client -o yaml \
   > /vagrant/.secrets/rsa-keys.ride-hailing-prod.secret.yaml
```

### Generate SealedSecret from one source Secret file (run inside cluster VM)

Use this general flow (no external host-side processing):

```bash
vagrant ssh k8s-master
cd /vagrant/.secrets

# 0) Always fetch the active controller certificate first
kubeseal --fetch-cert \
   --controller-namespace kube-system \
   --controller-name sealed-secrets-controller \
   > ./sealed-secrets-controller.crt

# 1) Pick one source Secret file and seal it in current directory
# Replace <source-secret-file> with one file in .secrets/
kubeseal --format yaml \
   --cert ./sealed-secrets-controller.crt \
   < ./<source-secret-file> > ./sealed-secret.generated.yaml

# 2) Copy or move ./sealed-secret.generated.yaml to the correct overlay file
# Example target pattern:
# /vagrant/ride-hail-gitops/apps/<service>/overlays/<env>/<sealed-secret-file>.yaml
```

After generating in current directory, copy the content into the corresponding overlay file and update `kustomization.yaml` if the filename is new.

### Prevent `Failed to unseal: no key could decrypt secret (private.pem, public.pem)`

- This error means the SealedSecret was encrypted with a different controller key/certificate.
- Always fetch current cert (`kubeseal --fetch-cert ...`) before sealing.
- If cluster/controller was recreated or rotated, re-seal affected source Secret files and commit new SealedSecret manifests.

### Overlay audit: ensure no plain Secret remains

Run inside `k8s-master` VM:

```bash
cd /vagrant
grep -R --line-number --include='*.yaml' 'kind: Secret' ride-hail-gitops/apps/*/overlays
```

Expected output: no result.

### Optional quick validation

```bash
kubectl kustomize /vagrant/ride-hail-gitops/apps/ride/overlays/dev >/dev/null
kubectl kustomize /vagrant/ride-hail-gitops/apps/dispatch/overlays/dev >/dev/null
kubectl kustomize /vagrant/ride-hail-gitops/apps/user/overlays/dev >/dev/null
```

### Troubleshooting: Prometheus CRD sync `metadata.annotations: Too long`

`ServerSideApply=true` is enabled in the ArgoCD app, but old CRDs can still carry oversized `last-applied` annotations from previous applies.

Run one-time cleanup in `k8s-master` VM:

```bash
for crd in $(kubectl get crd -o name | grep monitoring.coreos.com); do
   kubectl annotate "$crd" kubectl.kubernetes.io/last-applied-configuration- --overwrite || true
done
```

Then re-sync ArgoCD application `prometheus-operator-crds`.

### One-time emergency only (not GitOps standard)

If you must quickly unblock a broken pod, you can apply one source Secret file directly:

```bash
kubectl apply -f /vagrant/.secrets/<source-secret-file>
```

Then still convert and commit SealedSecret files to keep GitOps secure and consistent.
