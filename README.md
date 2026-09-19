# SerpHawk CRM --- AWS EKS Deployment

## Project Overview

SerpHawk CRM is a full-stack CRM application deployed on AWS using
Amazon EKS.

-   Frontend: Next.js / React
-   Backend: FastAPI
-   Database: PostgreSQL on Amazon RDS
-   Container registry: Amazon ECR
-   Infrastructure: AWS VPC + EKS + RDS using terraform
-   Kubernetes namespace: `serphawk`
-   AWS Region: `ap-south-1`

The deployment was completed incrementally, validating each layer before
moving to the next.

THE MAIN FOLDERS ARE --------------- 
   - Frontend  : holds the files which are required for frontend
   - Backend : main files for the backend 
   - K8s  : kubernetes manifests 
   - eks-tf  : eks cluster configurations using terraform 



## Final Architecture

``` text
                         INTERNET
                            |
                            v
                +------------------------+
                | Frontend AWS Load      |
                | Balancer :3000         |
                +-----------+------------+
                            |
                            v
                    +---------------+
                    | Next.js Pod   |
                    | EKS :3000     |
                    +-------+-------+
                            |
                     API Requests
                            |
                            v
                +------------------------+
                | Backend AWS Load       |
                | Balancer :8000         |
                +-----------+------------+
                            |
                            v
                    +---------------+
                    | FastAPI Pod   |
                    | EKS :8000     |
                    +-------+-------+
                            |
                            | PostgreSQL :5432
                            v
                    +---------------+
                    | RDS PostgreSQL|
                    | Private       |
                    +---------------+
```

## 1. AWS VPC and Networking

A dedicated VPC was created using Terraform.

### Network layout

``` text
VPC 10.0.0.0/16
|
+-- ap-south-1a
|   +-- Public Subnet  10.0.1.0/24
|   +-- Private Subnet 10.0.11.0/24
|
+-- ap-south-1b
    +-- Public Subnet  10.0.2.0/24
    +-- Private Subnet 10.0.12.0/24

Public Subnets
    |
    +-- Load Balancers

Private Subnets
    |
    +-- EKS Nodes
    +-- RDS

NAT Gateway
    |
    +-- Private subnet outbound access
```

Configuration included:

-   VPC CIDR `10.0.0.0/16`
-   Two Availability Zones
-   Public and private subnets
-   NAT Gateway
-   DNS hostnames
-   DNS support
-   Kubernetes load-balancer subnet tags

## 2. Amazon EKS

The EKS cluster was provisioned using Terraform.

### Cluster

-   Name: `serphawk-eks`
-   Kubernetes: `1.36`
-   Region: `ap-south-1`
-   IRSA enabled
-   Public and private API endpoint access
-   IAM/EKS access configured for administration

### Node Group

-   Name: `serphawk-node-group`
-   Instance type: `c7i-flex.large`
-   On-Demand
-   Minimum: 1
-   Desired: 1
-   Maximum: 2
-   Disk: 20 GB
-   Private subnets

### EKS Add-ons

``` text
EKS Cluster
|
+-- VPC CNI
+-- kube-proxy
+-- CoreDNS
```

These provide pod networking, Kubernetes service networking, and
internal DNS/service discovery.

## 3. Amazon ECR

Two private ECR repositories were used:

``` text
Amazon ECR
|
+-- serphawk-backend
|   +-- FastAPI container image
|
+-- serphawk-frontend
    +-- Next.js container image
```

The backend and frontend images were built locally, tagged for ECR,
authenticated through the AWS CLI, and pushed to their respective
repositories.

## 4. Amazon RDS PostgreSQL

PostgreSQL was deployed using Amazon RDS.

Configuration:

-   PostgreSQL 16
-   Instance: `db.t3.micro`
-   Storage: 20 GB gp3
-   Encryption enabled
-   Single-AZ
-   Database: `serphawk`
-   Port: `5432`
-   Private networking

The database was intentionally not exposed directly to the public
internet.

## 5. Database Security

``` text
Internet
   |
   X  Direct access blocked
   |
RDS PostgreSQL
   ^
   |
TCP 5432
   |
EKS Node Security Group
```

The RDS security group allows PostgreSQL traffic from the EKS node
security group.

Connectivity was independently tested from a temporary PostgreSQL pod
running in EKS.

The test confirmed:

-   EKS could reach RDS
-   PostgreSQL authentication worked
-   The `serphawk` database was accessible
-   Application tables could be created and queried

## 6. Kubernetes Namespace and Secrets

The application was deployed into:

``` text
serphawk
```

A Kubernetes Secret was used for the backend database connection.

The database credentials were not embedded into the container image.

Important security note: Kubernetes Secret values encoded with Base64
are not encryption. Secret manifests containing credentials should not
be committed to a public repository.

## 7. Backend Deployment

``` text
EKS
|
+-- Namespace: serphawk
    |
    +-- Deployment: serphawk-backend
        |
        +-- FastAPI Pod
        +-- Port 8000
        +-- Database Secret
        +-- Resource requests/limits
        +-- Readiness probe
        +-- Liveness probe
```

The backend image was pulled from ECR.

The FastAPI application started successfully and listened on port
`8000`.

## 8. Backend Load Balancer

The backend Kubernetes Service was changed to `LoadBalancer`.

``` text
Internet
   |
   v
Backend AWS Load Balancer :8000
   |
   v
Kubernetes Backend Service
   |
   v
FastAPI Pod :8000
   |
   v
RDS PostgreSQL
```

The API root endpoint was tested successfully and returned the
application's healthy response.

## 9. Frontend Deployment

The Next.js frontend was deployed separately.

``` text
EKS
|
+-- Namespace: serphawk
    |
    +-- Deployment: serphawk-frontend
        |
        +-- Next.js Pod
        +-- Port 3000
        +-- Resource requests/limits
```

The frontend image was built with the public backend API URL required by
browser-side requests.

This is important because a browser cannot resolve Kubernetes-internal
service names such as `backend:8000`.


## 10. Public Frontend

After internal validation, the frontend Service was made  to use 
`LoadBalancer`.

``` text
Internet
   |
   v
Frontend AWS Load Balancer :3000
   |
   v
Frontend Kubernetes Service
   |
   v
Next.js Pod
   |
   | API request
   v
Backend AWS Load Balancer :8000
```

The frontend became publicly accessible through its AWS Load Balancer.

## 11. Authentication Flow

An Admin account was created in the PostgreSQL `users` table.

The current application password implementation uses SHA-256.

``` text
User Browser
     |
     v
Next.js Login Page
     |
     | POST /login
     v
Backend AWS Load Balancer
     |
     v
FastAPI
     |
     v
PostgreSQL RDS
     |
     | User lookup
     v
Password validation
     |
     v
HTTP 200 OK
     |
     v
Authenticated application
```

The final login test returned:

``` text
POST /login
200 OK
```

## 12. Complete Deployment Flow

``` text
Application Source
       |
       v
Dockerize Frontend + Backend
       |
       v
Build Images
       |
       +----------------------+
       |                      |
       v                      v
Backend Image           Frontend Image
       |                      |
       v                      v
Amazon ECR              Amazon ECR
       |                      |
       +----------+-----------+
                  |
                  v
             Amazon EKS
                  |
        +---------+---------+
        |                   |
        v                   v
 Backend Deployment    Frontend Deployment
        |                   |
        v                   v
 Backend LB            Frontend LB
        |                   |
        +---------+---------+
                  |
                  v
             User Browser
                  |
                  v
             RDS PostgreSQL
```

## 13. Validation Performed

### Infrastructure

-   VPC created
-   Public/private subnets created
-   NAT Gateway configured
-   EKS cluster created
-   Worker node became Ready
-   EKS add-ons configured
-   IAM/EKS access validated

### Database

-   RDS PostgreSQL created
-   RDS kept private
-   Security groups configured
-   EKS-to-RDS connectivity tested
-   Application database accessed
-   Application tables created

### Backend

-   Backend image pushed to ECR
-   Backend Pod became Ready
-   FastAPI started successfully
-   Backend Load Balancer created
-   API endpoint returned `200 OK`

### Frontend

-   Frontend image pushed to ECR
-   Frontend Pod became Ready
-   Frontend tested with port forwarding
-   Frontend successfully reached backend
-   Frontend Load Balancer created
-   Public frontend access verified

### Authentication

-   Admin account created in RDS
-   Password hashing matched application implementation
-   `/login` returned `200 OK`

## 14. Current Status

``` text
AWS VPC
   |
   +-- Public Subnets
   |      |
   |      +-- Frontend Load Balancer
   |      +-- Backend Load Balancer
   |
   +-- Private Subnets
          |
          +-- EKS Nodes
          |     |
          |     +-- Next.js Pod
          |     +-- FastAPI Pod
          |
          +-- RDS PostgreSQL
```

The end-to-end application is currently working.

## 15. Current Limitations

The deployment is functional but can be made more production-oriented.

-   HTTPS has not yet been configured.
-   No custom domain is configured.
-   Frontend/backend replica counts are currently minimal.
-   Horizontal Pod Autoscaling has not been configured.
-   Centralized observability has not been added.
-   CI/CD is not currently part of this deployment.
-   The application currently uses SHA-256 for password hashing.
-   External secret management can be added.
-   Disaster recovery automation can be strengthened.


### Kubernetes Reliability

``` text
Deployments
   |
   v
Multiple Replicas
   |
   v
Rolling Updates
   |
   v
PodDisruptionBudget
   |
   v
HPA
   |
   v
High Availability
```

### DevSecOps : you can refer my DevSecops repo for this step 

``` text
GitHub
   |
   v
CI Pipeline
   |
   +-- Tests
   +-- SonarQube
   +-- Dependency Scan
   +-- Trivy
   +-- Docker Build
   |
   v
Amazon ECR
   |
   v
EKS
```

### GitOps

``` text
Developer
   |
   v
GitHub
   |
   v
Kubernetes Manifests / Helm
   |
   v
Argo CD
   |
   v
EKS
```

### Observability

``` text
EKS
 |
 +-- Application Logs
 +-- Kubernetes Metrics
 +-- Node Metrics
 +-- Application Metrics
          |
          v
Monitoring Platform
          |
          v
Dashboards + Alerts
```

### Disaster Recovery

``` text
RDS
 |
 v
Automated Backups
 |
 v
Snapshots
 |
 v
Recovery Strategy
 |
 v
Disaster Recovery Plan
```

## 16. Target DevSecOps Architecture

``` text
                         DEVELOPER
                             |
                             v
                         GITHUB
                             |
                             v
                    +----------------+
                    | CI PIPELINE    |
                    +----------------+
                    | Tests          |
                    | SonarQube      |
                    | Trivy          |
                    | Docker Build   |
                    +-------+--------+
                            |
                            v
                       AMAZON ECR
                            |
                            v
                         ARGO CD
                            |
                            v
                    +---------------+
                    | AMAZON EKS    |
                    +---------------+
                    | Frontend      |
                    | Backend       |
                    | HPA           |
                    | Monitoring    |
                    +-------+-------+
                            |
                            v
                     PRIVATE RDS
                            |
                            v
                  BACKUPS / DR PLAN
```

The next evolution is to add HTTPS, ALB routing, autoscaling,
observability, CI/CD, DevSecOps security scanning, Argo CD/GitOps,
secrets management, and disaster recovery.


## For Your REFERENCE : 
DevsecOps project : Check .github/workflows/main.yml 
link: https://github.com/himanshu2oo4/DevSecopsProject.git

Three tier Application DevSecOps: 
Link: https://github.com/himanshu2oo4/three-tier-application-devsecops.git

For K8s : 
link: https://github.com/himanshu2oo4/TaskManager-3tier-flask-k8s.git

