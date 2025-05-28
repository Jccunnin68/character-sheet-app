# Character Sheet Web Application

A monorepo containing a full-stack character sheet application with Node.js frontend, Go backend, PostgreSQL database, and AWS deployment infrastructure.

## Project Structure

```
character-sheet-app/
├── frontend/           # React/Node.js frontend application
├── backend/           # Go backend API service
├── database/          # PostgreSQL schema and migrations
├── terraform/         # AWS infrastructure as code
├── docker-compose.yml # Local development environment
└── README.md         # This file
```

## Services

- **Frontend**: React application for character sheet management
- **Backend**: Go REST API for character operations and authentication
- **Database**: PostgreSQL for storing character data and user accounts
- **Infrastructure**: Terraform for AWS deployment (ECS, RDS, ALB)

## Local Development

1. Install dependencies for each service
2. Run `docker-compose up` to start the local development environment
3. Frontend will be available at `http://localhost:3000`
4. Backend API will be available at `http://localhost:8080`

## Deployment

Use Terraform to deploy to AWS:
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Getting Started

See individual service READMEs for specific setup instructions:
- [Frontend Setup](./frontend/README.md)
- [Backend Setup](./backend/README.md)
- [Database Setup](./database/README.md)
- [Infrastructure Setup](./terraform/README.md) 