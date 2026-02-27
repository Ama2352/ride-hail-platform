# -*- mode: ruby -*-
# vi: set ft=ruby :

# =============================================================================
# ride-hail-platform — VM Topology (Total: 10 GB RAM)
#
# k8s-master    192.168.242.10  2048 MB  2 vCPU  Control plane + ArgoCD
# k8s-worker-1  192.168.242.11  3072 MB  2 vCPU  SonarQube + Prometheus + Grafana
# k8s-worker-2  192.168.242.12  2048 MB  2 vCPU  App workloads + Istio sidecars
# jenkins-vm    192.168.242.13  3072 MB  2 vCPU  Jenkins controller (DooD)
#
# Provisioning strategy:
#   - All configuration is driven by Ansible playbooks in ansible/.
#   - Workers/Jenkins: a minimal shell step installs Ansible first, then
#     ansible_local runs the appropriate playbook.
#   - The /vagrant synced folder is the bridge for the kubeadm join command
#     written by the master and consumed by the workers.
# =============================================================================

ANSIBLE_INSTALL = <<~SHELL
  apt-get update -qq
  apt-get install -y software-properties-common
  add-apt-repository --yes --update ppa:ansible/ansible
  apt-get install -y ansible
SHELL

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = false

  config.vm.provider "vmware_desktop" do |v|
    v.gui = false
    v.linked_clone = true
    v.allowlist_verified = true
  end

  # ===========================================================================
  # MASTER NODE (2 GB) — Control plane + ArgoCD (Phase 2)
  # ===========================================================================
  config.vm.define "k8s-master" do |master|
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", ip: "192.168.242.10"

    master.vm.provider "vmware_desktop" do |v|
      v.vmx["memsize"]  = "2048"
      v.vmx["numvcpus"] = "2"
    end

    master.vm.provision "shell", inline: ANSIBLE_INSTALL

    # Phase 1: K8s cluster init. Runs automatically on 'vagrant up'.
    master.vm.provision "ansible_local" do |ansible|
      ansible.playbook    = "ansible/playbook_master.yml"
      ansible.install_mode = "none"
      ansible.verbose     = false
    end

    # Phase 2: ArgoCD bootstrap. Run MANUALLY after all workers have joined:
    #   vagrant provision k8s-master --provision-with argocd
    master.vm.provision "argocd", run: "never", type: "ansible_local" do |ansible|
      ansible.playbook    = "ansible/playbook_argocd.yml"
      ansible.install_mode = "none"
      ansible.verbose     = false
    end
  end

  # ===========================================================================
  # WORKER NODE 1 (3 GB) — Tooling workloads
  # ===========================================================================
  config.vm.define "k8s-worker-1" do |worker|
    worker.vm.hostname = "k8s-worker-1"
    worker.vm.network "private_network", ip: "192.168.242.11"

    worker.vm.provider "vmware_desktop" do |v|
      v.vmx["memsize"]  = "3072"
      v.vmx["numvcpus"] = "2"
    end

    worker.vm.provision "shell", inline: ANSIBLE_INSTALL

    worker.vm.provision "ansible_local" do |ansible|
      ansible.playbook    = "ansible/playbook_worker.yml"
      ansible.install_mode = "none"
      ansible.verbose     = false
    end
  end

  # ===========================================================================
  # WORKER NODE 2 (2 GB) — Application workloads
  # ===========================================================================
  config.vm.define "k8s-worker-2" do |worker|
    worker.vm.hostname = "k8s-worker-2"
    worker.vm.network "private_network", ip: "192.168.242.12"

    worker.vm.provider "vmware_desktop" do |v|
      v.vmx["memsize"]  = "2048"
      v.vmx["numvcpus"] = "2"
    end

    worker.vm.provision "shell", inline: ANSIBLE_INSTALL

    worker.vm.provision "ansible_local" do |ansible|
      ansible.playbook    = "ansible/playbook_worker.yml"
      ansible.install_mode = "none"
      ansible.verbose     = false
    end

    # After the last worker joins, automatically trigger ArgoCD bootstrap on
    # the master. At this point both workers are Ready so the K8s scheduler
    # can place ArgoCD pods on workers — no taint manipulation needed.
    worker.trigger.after [:up, :provision] do |trigger|
      trigger.info = "Both workers joined — bootstrapping ArgoCD on k8s-master..."
      trigger.run = { inline: "vagrant provision k8s-master --provision-with argocd" }
    end
  end

  # ===========================================================================
  # JENKINS VM (3 GB) — Jenkins controller + Docker CI agents (DooD)
  # ===========================================================================
  config.vm.define "jenkins-vm" do |jenkins|
    jenkins.vm.hostname = "jenkins-vm"
    jenkins.vm.network "private_network", ip: "192.168.242.13"

    jenkins.vm.provider "vmware_desktop" do |v|
      v.vmx["memsize"]  = "3072"
      v.vmx["numvcpus"] = "2"
    end

    jenkins.vm.provision "shell", inline: ANSIBLE_INSTALL

    jenkins.vm.provision "ansible_local" do |ansible|
      ansible.playbook    = "ansible/playbook_jenkins.yml"
      ansible.install_mode = "none"
      ansible.verbose     = false
    end
  end
end
