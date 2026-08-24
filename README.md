# Patient Management - Microservices Platform

A 5-service microservices platform for patient management with JWT authentication, gRPC inter-service communication, Kafka event-driven messaging, and AWS infrastructure as code.

## Architecture

- Client requests enter through an Application Load Balancer to the API Gateway.
- API Gateway routes requests to the Auth and Patient services.
- Patient Service calls Billing Service synchronously via gRPC.
- Patient Service publishes events to Kafka, which are consumed asynchronously by the Analytics Service.

```text
                              ┌───────────────┐
                              │    Client     │
                              └───────┬───────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │ Application Load       │
                         │ Balancer (ALB)         │
                         └───────────┬────────────┘
                                     │
                                     ▼
                         ┌────────────────────────┐
                         │   API Gateway :4004    │
                         └───────┬─────────┬──────┘
                                 │         │
                        ┌────────┘         └────────┐
                        ▼                           ▼
                ┌──────────────┐            ┌───────────────┐
                │ Auth Service │            │Patient Service│
                │    :4005     │            │    :4000      │
                └──────────────┘            └──────┬────────┘
                                                   │
                                      ┌────────────┴────────────┐
                                      │                         │
                                   gRPC                      Kafka
                                synchronous              asynchronous
                                      │                         │
                                      ▼                         ▼
                              ┌───────────────┐        ┌─────────────────┐
                              │Billing Service│        │Analytics Service│
                              │ :4001 / :9001 │        │      :4002      │
                              └───────────────┘        └─────────────────┘
```

## Services

| Service | Port | Description |
|---|---:|---|
| API Gateway | 4004 | Spring Cloud Gateway with route-based routing and custom JWT validation filter |
| Auth Service | 4005 | JWT authentication with Spring Security and BCrypt password hashing |
| Patient Service | 4000 | CRUD REST API, gRPC client to Billing, Kafka producer |
| Billing Service | 4001, gRPC 9001 | gRPC server with Protocol Buffers |
| Analytics Service | 4002 | Kafka consumer processing patient events |

## Communication Patterns

- **REST** - Client requests go through API Gateway to Auth and Patient services.
- **gRPC** - Synchronous patient-to-billing communication via Protocol Buffers.
- **Kafka** - Asynchronous event-driven messaging (`PatientEvent`) from Patient Service to Analytics Service.

## Authentication

The platform uses JWT-based authentication with Spring Security.

- **JWT** - Used for authentication and authorization.
- **BCrypt** - Used for secure password hashing.
- **Auth Service** - Handles JWT token generation and validation.
- **API Gateway** - Uses a custom JWT validation filter.
- **Token Validation** - The gateway delegates token verification to the Auth Service before forwarding requests to protected downstream services.

## Patient Service

The Patient Service provides a REST-based CRUD API using Spring Data JPA and PostgreSQL.

It includes:

- Create, read, update, and delete patient operations
- Request validation
- DTO mapping
- Custom exception handling
- Global exception handler
- gRPC communication with the Billing Service
- Kafka event publishing

### Patient Registration Flow

When a patient is registered:

1. Patient Service creates the patient record.
2. Patient Service calls Billing Service synchronously via gRPC to create a billing account.
3. Patient Service publishes a `PatientEvent` to Kafka.
4. Analytics Service consumes the event asynchronously.

```text
                       Patient Service
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  gRPC                Kafka
              synchronous         asynchronous
                    │                   │
                    ▼                   ▼
           ┌────────────────┐   ┌─────────────────┐
           │ Billing Service│   │Analytics Service│
           │ Create Account │   │ Process Event   │
           └────────────────┘   └─────────────────┘
```

## AWS Infrastructure

Provisioned with **AWS CDK** and deployed to AWS.

![AWS Architecture](./AWS%20Architecture.png)

- **VPC**
  - 2 Availability Zones
  - Public subnet for the Application Load Balancer
  - Private subnets for ECS, RDS, and MSK

- **ECS Fargate**
  - ECS cluster
  - Containerized microservices
  - Cloud Map service discovery

- **RDS**
  - 2 PostgreSQL instances
  - Auth Service database
  - Patient Service database
  - Route 53 health checks

- **MSK**
  - Managed Streaming for Apache Kafka cluster
  - Patient Kafka topic

- **ALB**
  - Application Load Balancer
  - Public entry point for the API Gateway

## Tech Stack

- **Language:** Java 21
- **Backend:** Spring Boot, Spring Cloud Gateway, Spring Security, Spring Data JPA
- **Authentication:** JWT, BCrypt
- **Communication:** REST, gRPC, Protocol Buffers
- **Messaging:** Apache Kafka
- **Database:** PostgreSQL
- **Infrastructure:** AWS CDK, ECS Fargate, RDS, MSK, ALB, Cloud Map, Route 53
- **Containerization:** Docker
- **Testing:** REST Assured
- **Build:** Maven

## Testing

### Integration Tests

REST Assured integration tests are located in `integration-tests/`.

They cover:

- Authentication flow
  - Valid login
  - Invalid credentials
- Patient CRUD operations
- End-to-end requests through the API Gateway

### HTTP Request Files

Manual API testing files are available in `api-requests/` for:

- Auth Service
- Patient Service

### gRPC Request Files

Manual gRPC testing files are available in `grpc-requests/` for:

- Billing Service

## Docker

Each service has a multi-stage Dockerfile:

```text
┌─────────────────────┐
│   Maven Build Stage │
│                     │
│ Compile & Package   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ OpenJDK Runtime     │
│       Stage         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Containerized       │
│      Service        │
└─────────────────────┘
```

The multi-stage builds separate compilation from the runtime environment.

## Running Locally

Each service has a multi-stage Dockerfile using:

```text
Maven Build → OpenJDK Runtime
```

The infrastructure module can be used to deploy the full stack through AWS CDK.

### Prerequisites

- Java 21
- Maven
- Docker
- AWS CLI
- AWS CDK

### Setup

1. Clone the repository.

```bash
git clone https://github.com/ShriniwasMahajan/patient-management-microservices.git
cd patient-management-microservices
```

2. Configure the required environment variables.

3. Build the services using Maven.

4. Build and run the Docker containers.

5. Use the request files in `api-requests/` for manual REST API testing.

6. Use the request files in `grpc-requests/` for manual Billing Service gRPC testing.

### AWS Deployment

The infrastructure module contains the AWS CDK configuration for provisioning the required AWS resources.

```text
                              AWS
                               │
                               ▼
                         ┌───────────┐
                         │    ALB    │
                         │  Public   │
                         └─────┬─────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────┐
│                          VPC                             │
│                                                          │
│  ┌──────────────────────────┐   ┌─────────────────────┐  │
│  │    ECS Fargate Cluster   │   │   RDS - Private     │  │
│  │         Private          │   │       Subnet        │  │
│  │                          │   │                     │  │
│  │  ┌───────────────────┐   │   │  Auth Service DB    │  │
│  │  │ API Gateway :4004 │   │   │  Patient Service DB │  │
│  │  └───────────────────┘   │   │                     │  │
│  │                          │   └─────────────────────┘  │
│  │  ┌───────────────────┐   │                            │
│  │  │ Auth Service :4005│   │   ┌─────────────────────┐  │
│  │  └───────────────────┘   │   │  MSK - Private      │  │
│  │                          │   │       Subnet        │  │
│  │  ┌───────────────────┐   │   │                     │  │
│  │  │Patient Service    │   │   │ Patient Kafka Topic │  │
│  │  │     :4000         │   │   │                     │  │
│  │  └───────────────────┘   │   └─────────────────────┘  │
│  │                          │                            │
│  │  ┌───────────────────┐   │                            │
│  │  │Billing Service    │   │                            │
│  │  │ :4001 / gRPC 9001 │   │                            │
│  │  └───────────────────┘   │                            │
│  │                          │                            │
│  │  ┌───────────────────┐   │                            │
│  │  │Analytics Service  │   │                            │
│  │  │     :4002         │   │                            │
│  │  └───────────────────┘   │                            │
│  └──────────────────────────┘                            │
│                                                          │
│                  Cloud Map Service Discovery             │
└──────────────────────────────────────────────────────────┘
```

## Project Highlights

- 5 independently deployable microservices
- REST, gRPC, and Kafka communication patterns
- JWT authentication with Spring Security and BCrypt
- Synchronous inter-service communication with gRPC
- Asynchronous event-driven communication with Kafka
- AWS infrastructure provisioned using CDK
- ECS Fargate container deployment
- Cloud Map service discovery
- PostgreSQL persistence using Spring Data JPA
- Multi-stage Docker builds
- REST Assured integration testing
- Deployment architecture spanning 2 Availability Zones
