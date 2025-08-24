# Configuração para POC Laravel + Swoole
aws_region = "us-east-1"
environment = "poc"
project_name = "laravel-swoole-poc"
cluster_name = "laravel-swoole-cluster"

# Configuração ARM64 Graviton (melhor custo-benefício)
node_group_instance_types = ["t4g.medium"]  # ARM64 Graviton
node_group_desired_size = 2
node_group_max_size = 4
node_group_min_size = 1
use_spot_instances = true

# Simplificação para POC
enable_metrics_server = false  # Evitar problemas de timeout
enable_cluster_autoscaler = false  # Foco na aplicação
enable_alb_controller = false  # Simplificar primeiro deploy
enable_ebs_csi_driver = false  # Simplificar por enquanto
