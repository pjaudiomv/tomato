data "aws_ecr_repository" "tomato" {
  name = "tomato"
}

# IAM Role for ECS Service interaction with load balancer
resource "aws_iam_role" "tomato_lb" {
  name = "tomato-lb"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "tomato_lb" {
  name = "${aws_iam_role.tomato_lb.name}"
  role = "${aws_iam_role.tomato_lb.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# RDS
resource "aws_security_group" "tomato_rds" {
  name   = "tomato-rds"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.public_a.cidr_block}", "${aws_subnet.public_b.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "tomato" {
  name       = "tomato"
  subnet_ids = ["${aws_subnet.public_a.id}", "${aws_subnet.public_b.id}"]
}

resource "aws_db_instance" "tomato" {
  identifier        = "tomato"
  allocated_storage = 100
  engine            = "postgres"
  engine_version    = "9.5.10"
  instance_class    = "db.t2.small"
  storage_type      = "gp2"

  name     = "tomato"
  username = "tomato"
  password = "${var.rds_password}"
  port     = 5432

  apply_immediately      = true
  publicly_accessible    = true
  vpc_security_group_ids = ["${aws_security_group.tomato_rds.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.tomato.name}"

  skip_final_snapshot = true

  tags {
    application = "tomato"
    environment = "production"
  }
}

resource "aws_ecs_task_definition" "webapp" {
  family = "tomato-webapp"

  container_definitions = <<EOF
[
  {
    "volumesFrom": [],
    "extraHosts": null,
    "dnsServers": null,
    "disableNetworking": null,
    "dnsSearchDomains": null,
    "portMappings": [
      {
        "hostPort": 0,
        "containerPort": 8000,
        "protocol": "tcp"
      }
    ],
    "hostname": null,
    "essential": true,
    "entryPoint": null,
    "mountPoints": [],
    "name": "tomato",
    "ulimits": null,
    "dockerSecurityOptions": null,
    "environment": [
      {
        "name": "RDS_HOST",
        "value": "${aws_db_instance.tomato.address}"
      },
      {
        "name": "RDS_NAME",
        "value": "${aws_db_instance.tomato.name}"
      },
      {
        "name": "RDS_USER",
        "value": "${aws_db_instance.tomato.username}"
      },
      {
        "name": "RDS_PASSWORD",
        "value": "${aws_db_instance.tomato.password}"
      },
      {
        "name": "RDS_PORT",
        "value": "${aws_db_instance.tomato.port}"
      },
      {
        "name": "GOOGLE_MAPS_API_KEY",
        "value": "AIzaSyD4BPAvDHL4CiRcFORdoUCpqwVuVz1F9r8"
      },
      {
        "name": "SECRET_KEY",
        "value": "${var.secret_key}"
      }
    ],
    "links": [],
    "workingDirectory": "/code",
    "readonlyRootFilesystem": null,
    "image": "${data.aws_ecr_repository.tomato.repository_url}:latest",
    "command": [
      "sh",
      "-c",
      "python3 manage.py initialize && uwsgi --ini /code/uwsgi.ini"
    ],
    "user": null,
    "dockerLabels": null,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.tomato_webapp.name}",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "webapp"
      }
    },
    "cpu": 700,
    "privileged": null,
    "memoryReservation": 512,
    "linuxParameters": {
      "initProcessEnabled": true
    }
  }
]
EOF
}

resource "aws_ecs_task_definition" "tomato_root_server_import" {
  family = "tomato-root-server-import"

  container_definitions = <<EOF
[
  {
    "volumesFrom": [],
    "extraHosts": null,
    "dnsServers": null,
    "disableNetworking": null,
    "dnsSearchDomains": null,
    "portMappings": [],
    "hostname": null,
    "essential": true,
    "entryPoint": null,
    "mountPoints": [],
    "name": "tomato",
    "ulimits": null,
    "dockerSecurityOptions": null,
    "environment": [
      {
        "name": "RDS_HOST",
        "value": "${aws_db_instance.tomato.address}"
      },
      {
        "name": "RDS_NAME",
        "value": "${aws_db_instance.tomato.name}"
      },
      {
        "name": "RDS_USER",
        "value": "${aws_db_instance.tomato.username}"
      },
      {
        "name": "RDS_PASSWORD",
        "value": "${aws_db_instance.tomato.password}"
      },
      {
        "name": "RDS_PORT",
        "value": "${aws_db_instance.tomato.port}"
      }
    ],
    "links": [],
    "workingDirectory": "/code",
    "readonlyRootFilesystem": null,
    "image": "${data.aws_ecr_repository.tomato.repository_url}:latest",
    "command": [
      "sh",
      "-c",
      "python3 manage.py initialize && python3 manage.py import_root_servers"
    ],
    "user": null,
    "dockerLabels": null,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.tomato_root_server_import.name}",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "daemon"
      }
    },
    "cpu": 256,
    "privileged": null,
    "memoryReservation": 384,
    "linuxParameters": {
      "initProcessEnabled": true
    }
  }
]
EOF
}

resource "aws_ecs_service" "webapp" {
  name            = "webapp"
  cluster         = "${aws_ecs_cluster.main.id}"
  desired_count   = 2
  iam_role        = "${aws_iam_role.tomato_lb.name}"
  task_definition = "${aws_ecs_task_definition.webapp.arn}"

  deployment_minimum_healthy_percent = 50

  load_balancer {
    target_group_arn = "${aws_alb_target_group.tomato.id}"
    container_name   = "tomato"
    container_port   = 8000
  }

  depends_on = [
    "aws_iam_role_policy.tomato_lb",
    "aws_alb_listener.tomato_https",
  ]
}
