
data "template_file" "binaryauthorisation" {

  template = <<EOF
gcloud beta container clusters update --enable-binauthz --zone $${zone} $${name}
EOF

  vars {
    name       = "${var.name}"
    zone       = "${var.zone}"
    depends_on = "${join(",", var.depends_on)}"
  }
}

resource "null_resource" "binaryauthorisation" {
  provisioner "local-exec" {
    command = "${data.template_file.binaryauthorisation.rendered}"
  }
}