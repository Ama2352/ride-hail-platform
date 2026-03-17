# ride-hail-platform

> Infrastructure provisioning, Kubernetes bootstrap, and ArgoCD installation.
> Repo 1 of 3 in a GitOps architecture: platform -> services -> gitops.

No manual kubectl or helm operations are required after Day 0.
Cluster desired state is reconciled from the gitops repository by ArgoCD.

---

## Architecture Overview

```text
ride-hail-platform (this repo)
  -> creates VMs and bootstraps Kubernetes + ArgoCD
ride-hail-services
  -> builds/scans/pushes images with GitLab CI
ride-hail-gitops
  -> stores manifests/overlays watched by ArgoCD
```

---

## VM Topology

| VM | IP | RAM | vCPU | Role |
|---|---|---:|---:|---|
| k8s-master | 192.168.242.10 | 2 GB | 2 | Kubernetes control plane + ArgoCD |
| k8s-worker-1 | 192.168.242.11 | 3 GB | 2 | SonarQube, Prometheus, Grafana |
| k8s-worker-2 | 192.168.242.12 | 3 GB | 2 | Application workloads + Istio sidecars |
| jenkins-vm | 192.168.242.13 | 3 GB | 2 | Legacy Jenkins controller (DooD) |

Provider: vmware_desktop  
Base box: bento/ubuntu-22.04  
Network: 192.168.242.0/24

---

## Repository Structure

```text
ride-hail-platform/
  Vagrantfile
  k8s-join-command.sh
  run-sonarqube-ngrok.ps1
  ansible/
    inventory.ini
    playbook_master.yml
    playbook_worker.yml
    playbook_jenkins.yml
    playbook_argocd.yml
    playbook_ngrok_sonarqube.yml
```

---

## Quick Start

### Prerequisites
- Vagrant >= 2.3
- VMware Desktop + vagrant-vmware-desktop plugin
- At least 12 GB free RAM on host

### Provision Everything

```bash
vagrant up
```

This runs:
1. `playbook_master.yml` on k8s-master
2. `playbook_worker.yml` on both workers
3. Triggered `playbook_argocd.yml` after the second worker joins
4. `playbook_jenkins.yml` on jenkins-vm

### Re-run ArgoCD Only

```bash
vagrant provision k8s-master --provision-with argocd
```

---

## Access Endpoints

| Component | URL |
|---|---|
| ArgoCD | https://192.168.242.10:30080 |
| SonarQube | http://192.168.242.11:30090 |
| Grafana | http://192.168.242.11:30300 |
| Prometheus | http://192.168.242.11:30909 |
| Jenkins (legacy) | http://192.168.242.13:8080 |

---

## SonarQube ngrok Tunnel (Clean, Explicit Flow)

This repo now includes an optional Ansible provisioner that deploys an ngrok pod in Kubernetes and tunnels to SonarQube service (`sonarqube-sonarqube.sonarqube.svc.cluster.local:9000`).

### Option A: One-command helper script (Windows PowerShell)

```powershell
cd ride-hail-platform
.\run-sonarqube-ngrok.ps1 -NgrokAuthtoken "<YOUR_NGROK_AUTHTOKEN>"
```

The script explicitly runs and prints:
1. setting `NGROK_AUTHTOKEN`
2. `vagrant provision k8s-master --provision-with ngrok-sonarqube`
3. ngrok pod logs
4. extracted tunnel URL

### Option B: Manual explicit commands

```powershell
cd ride-hail-platform
$env:NGROK_AUTHTOKEN="<YOUR_NGROK_AUTHTOKEN>"
vagrant provision k8s-master --provision-with ngrok-sonarqube
vagrant ssh k8s-master -c "kubectl -n ngrok logs deploy/ngrok-sonarqube --tail=100"
```

### What gets created
- Namespace: `ngrok`
- Secret: `ngrok-authtoken`
- Deployment: `ngrok-sonarqube`

### Remove the tunnel

```bash
vagrant ssh k8s-master -c "kubectl delete namespace ngrok"
```

---

## Global Principles

1. Declarative: cluster state is defined in git.
2. Repo Separation: infra, app code, and desired state are separated.
3. Pull-Based CD: GitLab CI pushes images, ArgoCD pulls manifests.
4. Folders over Branches: environment differences live in overlays.
