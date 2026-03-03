# ride-hail-platform (Repo 1 of 3)

> Infrastructure, K8s cluster bootstrap, and ArgoCD installation.
> Part of a 3-repo GitOps architecture governed by `Global_Principles.md`.

---

## Architecture Position

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  ride-hail-platform │     │  ride-hail-services  │     │  ride-hail-gitops   │
│  >>> THIS REPO <<<  │     │      (Repo 2)        │     │      (Repo 3)       │
│                     │     │                      │     │                     │
│  Vagrant, Ansible,  │     │  Go source code,     │     │  K8s manifests,     │
│  K8s bootstrap,     │     │  Dockerfiles,        │     │  Helm values,       │
│  ArgoCD install     │     │  Jenkinsfile (CI)    │     │  ArgoCD App defs    │
└─────────────────────┘     └──────────┬───────────┘     └──────────▲──────────┘
                                       │  git commit image tag      │
                                       └───────────────────────────►┘
                                              ArgoCD reconciles
```

No `kubectl apply` or `helm install` is ever run manually after Day 0.
All cluster state flows through git commits to `ride-hail-gitops`.

---

## VM Topology (11 GB RAM Total)

| VM | IP | RAM | vCPU | Role |
|---|---|---|---|---|
| `k8s-master` | 192.168.242.10 | 2 GB | 2 | Control plane, CoreDNS, Calico, **ArgoCD** |
| `k8s-worker-1` | 192.168.242.11 | 3 GB | 2 | SonarQube · Prometheus · Grafana |
| `k8s-worker-2` | 192.168.242.12 | 3 GB | 2 | App workloads · Istio sidecars |
| `jenkins-vm` | 192.168.242.13 | 3 GB | 2 | Jenkins controller · Docker CI (DooD) |

Provider: `vmware_desktop` · Base box: `bento/ubuntu-22.04` · Network: `192.168.242.0/24`

---

## Repository Structure

```
ride-hail-platform/
├── Vagrantfile                  # Declarative VM definitions (source of truth)
└── ansible/
    ├── inventory.ini            # Static host inventory
    ├── playbook_master.yml      # Phase 1 — K8s control-plane init
    ├── playbook_worker.yml      # Phase 1 — Node OS prep + kubeadm join
    ├── playbook_jenkins.yml     # Phase 1 — Docker install + Jenkins container
    └── playbook_argocd.yml      # Phase 2 — ArgoCD bootstrap (after workers join)
```

---

## Quick Start

### Prerequisites
- [Vagrant](https://www.vagrantup.com/) ≥ 2.3
- VMware Desktop + [vagrant-vmware-desktop plugin](https://developer.hashicorp.com/vagrant/docs/providers/vmware)
- 10 GB free RAM on the host

### Phase 1 & 2 — Fully automatic (single command)

```bash
vagrant up
```

Vagrant provisions VMs in declaration order:
1. `k8s-master` — cluster is initialized, join token written to `/vagrant/k8s-join-command.sh`
2. `k8s-worker-1` — reads join token, joins cluster
3. `k8s-worker-2` — reads join token, joins cluster
   - A **Vagrant trigger** fires automatically after this step:
     `vagrant provision k8s-master --provision-with argocd`
4. `jenkins-vm` — Docker + Jenkins container provisioned (independent)

ArgoCD's pre-flight polls until workers are `Ready` before proceeding, so
the trigger timing is safe even if kubelet registration is still in progress.

### Manual re-run (if needed)
```bash
# Re-run ArgoCD bootstrap only (e.g. after a failed run)
vagrant provision k8s-master --provision-with argocd
```

### Access ArgoCD
ArgoCD is exposed via **NodePort 30080** on the master node — no port-forward needed.

```bash
# Open in browser (accept the self-signed cert)
https://192.168.242.10:30080

# Retrieve the initial admin password (run on your host)
vagrant ssh k8s-master -c "
  kubectl get secret argocd-initial-admin-secret -n argocd \
    -o jsonpath='{.data.password}' | base64 -d
"

# Login via CLI (optional)
argocd login 192.168.242.10:30080 \
  --username admin \
  --password <output from above> \
  --insecure
```

### Access Jenkins
Open `http://192.168.242.13:8080` in your browser.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| `ansible_local` for all VMs | Avoids host-side Ansible dependency; VM provisions itself |
| Vagrant synced folder as join-command bridge | Zero-config worker join without SSH key sharing |
| ArgoCD in Phase 2 (separate playbook) | Workers must exist first — ArgoCD is a workload, not a control-plane component |
| ArgoCD pinned to v2.x | v3.x init container uses `cp --update=none` (requires coreutils ≥ 9.1); Ubuntu 22.04 ships coreutils 8.32 |
| Pre-flight check in playbook_argocd.yml | Enforces correct sequencing; fails fast with a clear error if workers aren't Ready |
| No taint removal, no tolerations for ArgoCD | Standard scheduler placement on workers; control-plane protection remains intact |
| DooD for Jenkins CI | Sibling containers share the host Docker daemon; avoids DinD privilege risks |
| `folders > branches` for environments | Aligns with Global Principles; overlays live in Repo 3 |

---

## Global Principles

1. **Declarative** — Every state is described in Git. No manual `kubectl` or ad-hoc `sh` for final cluster state.
2. **Repo Separation** — Each repo owns a single concern: infrastructure, code, or desired state.
3. **Pull-Based CD** — Jenkins pushes images; ArgoCD pulls manifests from Repo 3.
4. **Folders > Branches** — Environment differences are directory overlays in Repo 3.
