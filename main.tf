provider "linode" {
  token = var.linode_token
}

resource "null_resource" "preflight-checks" {
  # Force re-run
  triggers = {
    key = uuid()
  }

  provisioner "local-exec" {
    command     = "${path.cwd}/${path.module}/scripts/local/preflight.sh \"${var.ccm_image}\" \"${var.csi_manifest}\" \"${var.calico_manifest}\""
    working_dir = "${path.cwd}/${path.module}"
  }
}

module "masters" {
  source       = "./modules/masters"
  label_prefix = var.cluster_name == "" ? terraform.workspace : var.cluster_name
  node_class   = "master"
  node_count   = var.masters
  node_type    = var.server_type_master
  linode_token = var.linode_token

  ubuntu_version    = var.ubuntu_version
  docker_version    = var.docker_version
  k8s_version       = var.k8s_version
  crictl_version    = var.crictl_version
  k8s_feature_gates = var.k8s_feature_gates
  cni_version       = var.cni_version
  ssh_public_key    = var.ssh_public_key
  region            = var.region
  linode_group      = var.cluster_name

  //todo variable instead of workspace?
  cluster_name = var.cluster_name == "" ? terraform.workspace : var.cluster_name
}

module "nodes" {
  source       = "./modules/nodes"
  label_prefix = var.cluster_name == "" ? terraform.workspace : var.cluster_name
  node_class   = "node"
  node_count   = var.nodes
  node_type    = var.server_type_node

  ubuntu_version       = var.ubuntu_version
  docker_version       = var.docker_version
  k8s_version          = var.k8s_version
  crictl_version       = var.crictl_version
  k8s_feature_gates    = var.k8s_feature_gates
  cni_version          = var.cni_version
  ssh_public_key       = var.ssh_public_key
  region               = var.region
  linode_group         = var.cluster_name
  kubeadm_join_command = module.masters.kubeadm_join_command
}

resource "null_resource" "local_kubectl" {
  // todo
  depends_on = [module.masters]

  provisioner "local-exec" {
    command    = "${path.cwd}/${path.module}/scripts/local/kubectl-conf.sh ${terraform.workspace} ${module.masters.k8s_master_public_ip} ${module.masters.k8s_master_private_ip} ${var.ssh_public_key}"
    on_failure = continue
  }
}
