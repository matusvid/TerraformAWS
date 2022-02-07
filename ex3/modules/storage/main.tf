resource "aws_instance" "mongo" {
  ami                    = "ami-02868af3c3df4b3aa"
  instance_type          = var.instance
  key_name               = var.keyname

  network_interface {
    network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface2.id
  }
  }

  user_data = filebase64("${path.module}/install.sh")

  tags = {
    Name  = "Mongo"
    Owner = "CloudAcademy"
  }
}