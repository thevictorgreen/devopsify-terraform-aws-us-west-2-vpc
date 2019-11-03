resource "aws_instance" "sample-machine" {
  count         = "${var.sample_machine_count}"
  ami           = "${var.amis["ubuntu_18_04"]}"
  instance_type = "${var.instance_type["micro"]}"

  key_name      = "${var.keypairs["kp_1"]}"
  subnet_id     = "${var.subnets["AAAAA002uswest2-public-us-west-2a-sn"]}"

  vpc_security_group_ids = [
    "${var.secgroups["AAAAA002uswest2-bastion-security-group"]}"
  ]

  connection {
    private_key = "${file(var.private_key)}"
    user        = "${var.ansible_user["ubuntu_18_04"]}"
    host        = "${aws_instance.sample-machine[count.index].public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo waiting-for-boot-finished; sleep 5; done;",
      "while [ ! -z \"$(lsof /var/lib/dpkg/lock-frontend)\" ]; do echo cloud-init-configuring-system; sleep 5; done;",
      "sudo hostnamectl set-hostname ${var.sample_machine_name}${count.index}.${var.domain}"
    ]
  }

  tags = {
    Name = "${var.sample_machine_name}${count.index}"
    region = "us-west-2"
    env = "AAAAA"
    AnsibleRole = "sample"
    ClusterRole = "none"
  }
}


resource "aws_route53_record" "sample-machine-private-record" {
  count   = "${var.sample_machine_count}"
  zone_id = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name    = "${var.sample_machine_name}${count.index}.${data.aws_route53_zone.dns_private_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.sample-machine[count.index].private_ip}"]
}


resource "aws_route53_record" "sample-machine-reverse-record" {
  count   = "${var.sample_machine_count}"
  zone_id = "${data.aws_route53_zone.dns_reverse_zone.zone_id}"
  name    = "${element(split(".", aws_instance.sample-machine[count.index].private_ip),3)}.${element(split(".", aws_instance.sample-machine[count.index].private_ip),2)}.${data.aws_route53_zone.dns_reverse_zone.name}"
  records = ["${var.sample_machine_name}${count.index}.${data.aws_route53_zone.dns_private_zone.name}"]
  type    = "PTR"
  ttl     = "300"
}


resource "aws_eip" "sample-machine-eip" {
  count    = "${var.sample_machine_count}"
  instance = "${aws_instance.sample-machine[count.index].id}"
  vpc      = true
}


resource "aws_route53_record" "sample-machine-public-record" {
  count   = "${var.sample_machine_count}"
  zone_id = "${data.aws_route53_zone.dns_public_zone.zone_id}"
  name    = "${var.sample_machine_name}${count.index}.${data.aws_route53_zone.dns_public_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.sample-machine-eip[count.index].public_ip}"]
}
