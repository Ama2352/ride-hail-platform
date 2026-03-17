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
