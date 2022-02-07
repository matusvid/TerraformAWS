resource "aws_launch_template" "launchInstances" {
  name          = "launchInstances"
  instance_type = var.instance
  key_name      = var.keyname
  image_id      = var.ami

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.security.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }

  user_data = base64encode(data.template_cloudinit_config.config.rendered)
}

data "template_cloudinit_config" "config" {
  gzip          = false
  base64_encode = false

  #userdata
  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #! /bin/bash
    apt-get -y update
    apt-get -y install nginx
    apt-get -y install jq
    ALB_DNS=${aws_lb.alb1.dns_name}
    MONGODB_PRIVATEIP=${var.mongodb_ip}
    
    mkdir -p /tmp/cloudacademy-app
    cd /tmp/cloudacademy-app
    echo ===========================
    echo FRONTEND - download latest release and install...
    mkdir -p ./voteapp-frontend-react-2020
    pushd ./voteapp-frontend-react-2020
    curl -sL https://api.github.com/repos/cloudacademy/voteapp-frontend-react-2020/releases/latest | jq -r '.assets[0].browser_download_url' | xargs curl -OL
    INSTALL_FILENAME=$(curl -sL https://api.github.com/repos/cloudacademy/voteapp-frontend-react-2020/releases/latest | jq -r '.assets[0].name')
    tar -xvzf $INSTALL_FILENAME
    rm -rf /var/www/html
    cp -R build /var/www/html
    cat > /var/www/html/env-config.js << EOFF
    window._env_ = {REACT_APP_APIHOSTPORT: "$ALB_DNS"}
    EOFF
    popd
    echo ===========================
    echo API - download latest release, install, and start...
    mkdir -p ./voteapp-api-go
    pushd ./voteapp-api-go
    curl -sL https://api.github.com/repos/cloudacademy/voteapp-api-go/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .browser_download_url' | xargs curl -OL
    INSTALL_FILENAME=$(curl -sL https://api.github.com/repos/cloudacademy/voteapp-api-go/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .name')
    tar -xvzf $INSTALL_FILENAME
    #start the API up...
    MONGO_CONN_STR=mongodb://$MONGODB_PRIVATEIP:27017/langdb ./api &
    popd
    systemctl restart nginx
    systemctl status nginx
    echo fin v1.00!
    EOF    
  }
}

resource "aws_lb" "lb1" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "tg-webserver" {
  name     = "example"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mainVPC.id
}

resource "aws_lb_target_group" "tg-api" {
  name     = "example"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.mainVPC.id
}

resource "aws_lb_listener" "lb-list" {
  load_balancer_arn = aws_lb.lb1.id
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.webserver.id
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.lb-list.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}


resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.lb-list.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = [
        "/languages",
        "/languages/*",
        "/languages/*/*",
        "/ok"
      ]
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "foobar3-terraform-test"
  max_size                  = 2
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.subnet3.id, aws_subnet.subnet4.id]
  

  target_group_arns = [aws_lb_target_group.webserver.arn, aws_lb_target_group.api.arn]

  launch_template {
    id      = aws_launch_template.launchInstances.id
    version = "$Latest"
  }

}

data "aws_instances" "application" {
  instance_tags = {
    Name  = "FrontendApp"
    Owner = "CloudAcademy"
  }

  instance_state_names = ["pending", "running"]

  depends_on = [
    aws_autoscaling_group.asg
  ]
}


