terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }   
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}


variable "eks_cluster_name" {
  default = "my-eks-cluster"
}

# Security Groups
resource "aws_security_group" "eks_cluster_sg" {
  name        = "my-eks-cluster-eks-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = data.aws_vpc.default.id   #aws_vpc.eks_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
  }

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port   = 443
    to_port     = 443
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
    Name = "my-eks-cluster-eks-cluster-sg"
  }
}

resource "aws_security_group" "eks_node_sg" {
  name        = "my-eks-cluster-eks-node-sg"
  description = "EKS worker node security group"
  vpc_id      = data.aws_vpc.default.id  

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }


  ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  security_groups = [aws_security_group.eks_cluster_sg.id]
}


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-eks-cluster-eks-node-sg"
  }
  depends_on = [
    aws_security_group.eks_cluster_sg
  ]
}


# IAM Roles and Attachments
resource "aws_iam_role" "eks_role" {
  name = "eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  depends_on = [
    aws_iam_role.eks_role
  ]
}

resource "aws_iam_role_policy_attachment" "CloudWatch_eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  depends_on = [
    aws_iam_role.eks_role
  ]
}

resource "aws_iam_role_policy_attachment" "AutoScaling_eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  depends_on = [
    aws_iam_role.eks_role
  ]
}
resource "aws_iam_role_policy_attachment" "Service_eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  depends_on = [
    aws_iam_role.eks_role
  ]
}


resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  depends_on = [
    aws_iam_role.eks_node_group_role
  ]
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  depends_on = [
    aws_iam_role.eks_node_group_role
  ]
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  depends_on = [
    aws_iam_role.eks_node_group_role
  ]
}

resource "aws_iam_role_policy_attachment" "eks_elb_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  depends_on = [
    aws_iam_role.eks_node_group_role
  ]
}

resource "aws_iam_role_policy_attachment" "CloudWatch_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  depends_on = [
    aws_iam_role.eks_node_group_role
  ]
}

resource "aws_iam_role_policy_attachment" "AutoScaling_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  depends_on = [
    aws_iam_role.eks_node_group_role
  ]
}


# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids         = ["subnet-04c001c3056ef26d1", "subnet-0a9dfb92318f8a2d7"] 
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role.eks_role,
    aws_iam_role_policy_attachment.eks_policy,
    aws_security_group.eks_cluster_sg
  ]
}

# EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids = ["subnet-04c001c3056ef26d1", "subnet-0a9dfb92318f8a2d7"]   
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  instance_types = ["t3.medium"]
  remote_access {
    ec2_ssh_key = "newkey"  
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.eks_node_group_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_elb_policy,
    aws_iam_role_policy_attachment.eks_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy,
    aws_iam_role.eks_role,
    aws_iam_role.eks_node_group_role,
    aws_security_group.eks_cluster_sg
  ]
}





# Data Source to Retrieve ASG Name Associated with the EKS Node Group
data "aws_autoscaling_groups" "eks_node_asg" {
  filter {
    name   = "tag:eks:nodegroup-name"
    values = [aws_eks_node_group.eks_node_group.node_group_name]
  }
  
  filter {
    name   = "tag:eks:cluster-name"
    values = [aws_eks_cluster.eks_cluster.name]
  }
}

# Output to Verify Retrieved ASG Names (Optional)
output "eks_node_asg_names" {
  value = data.aws_autoscaling_groups.eks_node_asg.names
}

# Auto Scaling Policy for Scaling Up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  autoscaling_group_name = data.aws_autoscaling_groups.eks_node_asg.names[0]
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300

  depends_on = [
    aws_eks_node_group.eks_node_group
  ]
}

# (Opsiyonel) Auto Scaling Policy for Scaling Down
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  autoscaling_group_name = data.aws_autoscaling_groups.eks_node_asg.names[0]
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300

  depends_on = [
    aws_eks_node_group.eks_node_group
  ]
}

# CloudWatch Metric Alarm for High CPU Utilization (Scaling Up)
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"  # CPU kullanım eşiği (%70)
  
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = data.aws_autoscaling_groups.eks_node_asg.names[0]
  }

  depends_on = [
    aws_autoscaling_policy.scale_up
  ]
}

#CloudWatch Metric Alarm for Low CPU Utilization (Scaling Down)
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = "low-cpu-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"  
  
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = data.aws_autoscaling_groups.eks_node_asg.names[0]
  }

  depends_on = [
    aws_autoscaling_policy.scale_down
  ]
}

