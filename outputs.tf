output "elb_dns" {
  description = "O DNS público do Load Balancer"
  value       = aws_lb.app_lb.dns_name
}

output "db_instance_endpoint" {
  description = "Endpoint do banco de dados RDS"
  value       = aws_db_instance.app_db.endpoint
}
