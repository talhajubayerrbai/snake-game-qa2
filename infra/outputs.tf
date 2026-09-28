output "public_ip" {
  value       = aws_eip.snake.public_ip
  description = "Elastic IP attached to the snake-game-qa2 instance"
}

output "instance_id" {
  value       = aws_instance.snake.id
  description = "EC2 instance ID"
}
