# AWS Cloud Infrastructure Orchestration with Terraform, Ansible, and Spacelift

## INTRODUCTION
Provisioning and configuring cloud infrastructure represent two fundamental pillars of DevOps engineering. 
While Terraform excels at declarative infrastructure provisioning, it lacks scalability for complex configuration management; conversely, configuration tools like Ansible manage server state effectively but fall short in large-scale infrastructure provisioning due to architectural immaturity.
The industry-standard solution to this operational challenge is combining Terraform for infrastructure creation and Ansible for configuration management, governed by an orchestration layer. 

An orchestrator defines execution order, enforces compliance guardrails, implements Role-Based Access Control (RBAC), manages tool upgrades, and securely integrates with cloud providers like AWS, Azure, and GCP.
This project guide details the implementation of an end-to-end GitOps and orchestration workflow using Spacelift to orchestrate Terraform provisioning of AWS EC2 instances, dynamically pass runtime instance IP outputs to Ansible, and execute configuration playbooks securely.

##### PDF GUIDE: [AWS CLOUD INFRASTRUCTURE ORCHESTRATION WITH TERRAFORM AND ANSIBLE.pdf](https://github.com/user-attachments/files/34540908/AWS.CLOUD.INFRASTRUCTURE.ORCHESTRATION.WITH.TERRAFORM.AND.ANSIBLE.pdf)

##### WATCH VIDEO WALKTHROUGH HERE: https://youtu.be/eejnOzTIFw0


### STEP-BY-STEP DEPLOYMENT GUIDE

#### STEP 1: Create Terraform and Ansible Configuration Files on GitHub

1) Initialize the Repository:
   Create a new GitHub repository named orchestrating-terraform-and-ansible-with-spacelift with a .gitignore file, and clone it into your development environment.

2) Create Project Directory Structure & SSH Key Pair:
   Generate an RSA key pair (ansible_key) for secure, passwordless remote access from Spacelift workers to your AWS EC2 instances.

   <PRE>mkdir -p tf-ansible-stack-files/terraform-configurations</PRE>
   <PRE>mkdir -p tf-ansible-stack-files/ansible-configurations</PRE>
   <PRE>cd tf-ansible-stack-files</PRE>

   Generate private and public SSH keys (PEM format)
   <PRE>ssh-keygen -t rsa -b 4096 -m PEM -f ./ansible_key -C "ansible-spacelift" -N ""</PRE>

   *Ensure you add `ansible_key` and `ansible_key.pub` to your `.gitignore` file to prevent leaking sensitive secrets to GitHub.*

3) Write Terraform Configuration (main.tf, variables.tf, outputs.tf):
   Inside terraform-configurations/, create main.tf to provision an AWS provider (eu-north-1), an SSH key pair resource, a security group allowing SSH access, and two t3.micro Ubuntu EC2 instances.

   Create variables.tf to accept the public key path.

   Create outputs.tf to export public IPs for dynamic inventory consumption.

   Write Ansible Configuration (install_htop.yml):
   Inside ansible-configurations/, create an playbook to install htop on target hosts:

   Commit and push your code changes to GitHub.


#### STEP 2: Configure Spacelift Infrastructure Orchestrator

1) Sign Up & Create a Space:
   Register on Spacelift using your GitHub or Google account.
   Navigate to Spaces > Create Space, name it terraform-ansible-space, and set the parent space to root.

2) Create a Key Context:
   Under your space, go to Contexts > Create Context, name it ansible_keys, and attach your generated private (ansible_key) and public (ansible_key.pub) SSH keys as mounted files.

3) Create the Terraform Stack:
   Navigate to Stacks > Create Stack, name it terraform-stack, and assign it to terraform-ansible-space.
   Set your GitHub repository URL and configure the project root to tf-ansible-stack-files/terraform-configurations.
   Choose Terraform (FOSS) as the vendor workflow and attach the ansible_keys context.

4) Integrate AWS Cloud Provider:
   Create an IAM Role in your AWS account using a custom trust policy generated from Spacelift's Integrations > AWS configuration page, granting AdministratorAccess.
   Copy the created IAM Role ARN into Spacelift's AWS integration settings.
   Attach the AWS integration to your terraform-stack with read/write access.

5) Trigger Terraform Provisioning:
   Trigger a run on terraform-stack and confirm the deployment to provision the EC2 instances in AWS.


#### STEP 3: Configure Ansible Stack & Runtime HooksCreate the Ansible Stack:

1) Create a new stack named ansible-stack under terraform-ansible-space pointing to the root path tf-ansible-stack-files/ansible-configurations.
   Select Ansible as the vendor, specify install_htop.yml as the playbook, and enable secret masking.

2) Configure Execution Hooks:
   In the stack's Behavior > Hooks configuration, add Before planning and applying hooks to securely format permissions and construct a dynamic inventory file (inventory.ini) from Terraform's runtime outputs:

   Grant strict read/write permissions to private key
   <PRE>chmod 600 /mnt/workspace/ansible_key</PRE>

   Dynamically generate inventory.ini from Terraform instance outputs:
```
   echo "[servers]" > /mnt/workspace/inventory.ini
for instance in $(echo "$instances" | tr -d '[]"' | tr ',' ' '); do
  echo "$instance ansible_user=ubuntu ansible_ssh_private_key_file=/mnt/workspace/ansible_key" >> /mnt/workspace/inventory.ini
done
```

   Verify inventory population
   <PRE>cat /mnt/workspace/inventory.ini</PRE>

3) Define Environment Variables:
   Under the stack's Environment tab, add the following variables:
   ANSIBLE_PRIVATE_KEY_FILE: /mnt/workspace/ansible_key
   ANSIBLE_REMOTE_USER: ubuntu
   ANSIBLE_INVENTORY: /mnt/workspace/inventory.ini


#### STEP 4: Define Stack Dependencies & Execute End-to-End Orchestration

1) Link Stack Dependencies:
   Navigate to terraform-stack, select the Dependencies tab, and add ansible-stack as a downstream dependency.
   Map the aws_instances output from Terraform to an input variable named instances for Ansible.

2) Trigger Configuration Management:
   Trigger ansible-stack.
   Spacelift will automatically execute the Terraform dependency, extract the newly created EC2 public IP addresses into the dynamic inventory, and run the install_htop.yml playbook to configure the remote servers seamlessly.
   
   
