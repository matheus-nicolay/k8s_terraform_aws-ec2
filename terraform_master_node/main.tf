data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "kubernetes_master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = "kubernetes_cluster_key" # Insira o nome da chave criada antes.
  subnet_id = var.subnet_public_id
  vpc_security_group_ids = [aws_security_group.permitir_ssh_http.id]
  associate_public_ip_address = true

  cpu_core_count = 2

  tags = {
    Name = "kubernetes_master"
    # Insira o nome da instância de sua preferência.
  }

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("../kubernetes_cluster_key.pem")
    host     = self.public_ip
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "/tmp/script.sh args",
      "sudo hostnamectl set-hostname master-node",
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml",
      "kubectl get pods --all-namespaces"
      #"consul join ${aws_instance.web.private_ip}",
    ]
  }
}

variable "vpc_id" {
  default = "vpc-062c086ef04d859d5" # Orientações para copia da VPC ID abaixo.
}

variable "subnet_public_id" {
  default = "subnet-0b2539833726bb46d" # Orientações para copia da Subnet ID abaixo.
}


resource "aws_security_group" "permitir_ssh_http" {
  name        = "permitir_ssh"
  description = "Permite SSH e HTTP na instancia EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH to EC2"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP to EC2"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "permitir_ssh_e_http"
  }

}
