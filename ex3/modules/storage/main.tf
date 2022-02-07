resource "aws_instance" "mongo" {
  ami                    = var.ami
  instance_type          = var.instance
  key_name               = var.keyname

  network_interface {
    device_index         = 0
    network_interface_id = 
  }
  
  user_data = filebase64("${path.module}/install.sh")

  tags = {
    Name  = "Mongo"
    Owner = "CloudAcademy"
  }
}