output "aws_instances" {
  value = [for instance in aws_instance.this : instance.public_ip]   # a for loop that prints the 
                                                                     # public IP addresses of the created instances
}