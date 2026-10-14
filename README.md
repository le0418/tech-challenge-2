# Tech Challenge 2 — AWS EKS, Terraform, Helm & Jenkins CI/CD

## Project Overview

This project demonstrates the deployment of a containerized Python Flask application to Amazon Elastic Kubernetes Service (EKS), using Terraform for infrastructure provisioning, Docker for containerization, Helm for Kubernetes application management, and Jenkins for CI/CD automation.

The solution includes an AWS Application Load Balancer (ALB), Amazon Elastic Container Registry (ECR), Kubernetes Horizontal Pod Autoscaler (HPA), and application health verification.

## Architecture

```text
GitHub Repository
       |
       v
Jenkins CI/CD Pipeline
       |
       +--> Docker Build
       |
       +--> Amazon ECR
       |
       +--> Helm Upgrade / Install
                    |
                    v
               Amazon EKS
                    |
             Flask Application
                    |
           Kubernetes Service
                    |
          AWS Application Load Balancer
                    |
                 HTTP Client
```

### AWS Infrastructure

Terraform provisions:

- A VPC with CIDR `10.20.0.0/16`
- Two public subnets across `us-east-1a` and `us-east-1b`
- Two private subnets across the same Availability Zones
- An Internet Gateway and a single NAT Gateway
- An Amazon EKS cluster named `tech-challenge-2-eks`
- An EKS managed node group using `t3.small` instances
- Amazon ECR repository `tech-challenge-2`
- IAM roles and supporting infrastructure through the Terraform modules

The EKS worker nodes are deployed into private subnets.

## Technology Stack

| Component | Technology |
|---|---|
| Cloud platform | Amazon Web Services |
| Infrastructure as Code | Terraform |
| Containerization | Docker |
| Application | Python Flask |
| Container registry | Amazon ECR |
| Container orchestration | Amazon EKS / Kubernetes |
| Application packaging | Helm |
| CI/CD automation | Jenkins |
| Ingress | AWS Application Load Balancer |
| Autoscaling | Kubernetes HPA |
| Source control | GitHub |

## Repository Structure

```text
tech-challenge-2/
├── .dockerignore
├── .gitignore
├── Dockerfile
├── Jenkinsfile
├── README.md
├── app/
│   ├── app.py
│   └── requirements.txt
├── flask-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── terraform/
    ├── .terraform.lock.hcl
    ├── ecr.tf
    ├── eks.tf
    ├── outputs.tf
    ├── providers.tf
    ├── variables.tf
    └── vpc.tf
```

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured for the target account
- Terraform 1.5 or later
- Docker
- kubectl
- Helm
- Jenkins with the required tools and AWS credentials
- Git

## Infrastructure Deployment

From the Terraform directory:

```powershell
cd terraform
terraform init
terraform fmt -check -diff
terraform validate
terraform plan
```

Review the Terraform plan carefully before any infrastructure changes.

To provision infrastructure in an appropriate environment:

```powershell
terraform apply
```

**Important:** This project has known configuration drift involving the EKS API endpoint CIDR allowlist and an AWS Load Balancer Controller-managed security group rule. Do not apply the configuration to the existing deployed environment without first reconciling those differences.

## Application Containerization

The Flask application is packaged using the repository's `Dockerfile`.

Build the image locally:

```powershell
docker build -t tech-challenge-2:local .
```

The Jenkins pipeline builds the application image and publishes it to Amazon ECR.

## Kubernetes Deployment with Helm

The Helm chart is stored in `flask-chart/`.

Inspect the chart:

```powershell
helm lint ./flask-chart
```

Deploy or update the application:

```powershell
helm upgrade --install flask-app ./flask-chart --namespace default
```

The Jenkins pipeline performs the production deployment workflow using the container image published to ECR.

## Jenkins CI/CD Pipeline

The repository includes a declarative `Jenkinsfile`.

The pipeline performs these stages:

1. Checkout the GitHub source repository.
2. Validate the application source.
3. Build the Docker image.
4. Authenticate with AWS and push the image to Amazon ECR.
5. Deploy the image to Amazon EKS using Helm.
6. Verify the Kubernetes deployment rollout.

### Verified Pipeline Execution

Jenkins job: `tech-challenge-2-cicd`

Successful build: `#2`

Published image:

```text
900160666800.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-2:build-2
```

The ECR image was verified after the pipeline completed.

## Application Autoscaling

The Flask deployment uses a Kubernetes Horizontal Pod Autoscaler.

Configured HPA values:

| Setting | Value |
|---|---|
| Minimum replicas | 1 |
| Maximum replicas | 4 |
| CPU utilization target | 50% |
| Memory utilization target | 50% |
| CPU request | 50m |
| CPU limit | 250m |
| Memory request | 96Mi |
| Memory limit | 256Mi |

The HPA was observed with active CPU and memory metrics and two running replicas following the Jenkins deployment.

**Validation scope:** HPA configuration and metrics availability were verified. Scaling behavior under sustained load was not tested.


## Cluster Autoscaler and Pod Scheduling

The Amazon EKS managed node group uses t3.small EC2 instances with a minimum of 1 and a maximum of 4 worker nodes.

Cluster Autoscaler is installed in the kube-system namespace using Helm and IAM Roles for Service Accounts (IRSA).

### Verified Autoscaling Tests

| Test | Observed result |
|---|---|
| Initial scale-up | 1 to 2 worker nodes |
| Initial scale-down | 2 to 1 worker node |
| Rolling deployment scale-up | 1 to 3 worker nodes |
| Post-deployment scale-down | 3 to 2 worker nodes |
| Flask availability | 2/2 replicas Ready |
| Pod placement | Separate worker nodes |

### Pod Anti-Affinity

The Flask deployment uses required pod anti-affinity with the kubernetes.io/hostname topology key.

This prevents Flask replicas from being scheduled on the same worker node.

### Rolling Update Strategy

The Helm chart configures:

- maxSurge: 1
- maxUnavailable: 0

These settings allow a rolling update to retain existing replicas while replacement pods become available, provided the cluster has sufficient capacity.

### Verified Jenkins Deployment

Jenkins build #2 completed successfully.

- ECR image: `900160666800.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-2:build-2`
- Helm release: `flask-app`
- Helm revision: 12
- Flask deployment: 2/2 Ready
- Pod restarts: 0
- Required pod anti-affinity: Verified
- Application endpoint: HTTP 200, Hello, World!
- Health endpoint: HTTP 200

The Jenkins pipeline passes flask-chart/values.yaml to Helm to preserve the pod scheduling configuration.

## Deployment Verification

The following checks were completed successfully:

- Terraform formatting and configuration validation
- Terraform infrastructure state inspection
- Jenkins declarative pipeline syntax validation
- Successful Jenkins build #2
- Docker image publication to Amazon ECR
- Helm application deployment
- Kubernetes deployment rollout
- Two ready application replicas
- HPA metrics inspection
- HTTP 200 response from the Flask health endpoint

### Health Endpoint

```text
http://k8s-default-flaskapp-984b2761fd-1453430924.us-east-1.elb.amazonaws.com/health
```

The endpoint returned HTTP 200 with a JSON response containing `status: healthy` during verification.

The ALB hostname is environment-specific and may change if the load balancer is recreated.

## Security Considerations

- AWS credentials are not hardcoded in the reviewed Terraform configuration.
- Jenkins uses configured credentials for AWS authentication.
- EKS worker nodes are deployed in private subnets.
- EKS API public access is restricted using CIDR allowlisting.
- Amazon ECR uses AES-256 encryption and image scanning on push.
- Terraform state files, saved plans, and credential files are excluded from Git tracking.

### Known Configuration Drift

A Terraform refresh-only plan identified differences between the configuration and deployed infrastructure:

1. The live EKS public API endpoint allowlist includes `185.242.5.18/32`, which is not included in the committed `eks.tf` allowlist.
2. An inbound TCP port 5000 security group rule exists for communication associated with the AWS Load Balancer Controller.

These differences should be reconciled before a future `terraform apply`. No infrastructure changes were made during the final Terraform validation and GitHub preparation process.

## Limitations and Production Improvements

This deployment is intended as a technical challenge demonstration.

Potential production improvements include:

- Using NAT Gateways across multiple Availability Zones for improved availability.
- Using immutable image tags and image digest pinning.
- Migrating Jenkins AWS access keys to short-lived role-based authentication.
- Managing Terraform state in a secured remote backend with appropriate locking.
- Performing application load tests to verify HPA scale-out and scale-in behavior.
- Adding centralized monitoring, alerting, and structured application logs.
- Reconciling Terraform drift and documenting ownership of controller-managed resources.
- Implementing stronger deployment controls and least-privilege access.

## Project Outcome

Successfully demonstrated an end-to-end deployment workflow combining AWS infrastructure provisioning, containerization, Kubernetes orchestration, Helm application management, Jenkins CI/CD automation, and Kubernetes autoscaling configuration.

The Jenkins pipeline completed successfully and deployed a verified Flask application to Amazon EKS.