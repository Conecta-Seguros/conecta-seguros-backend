# Conecta Seguros Backend - Project Context

## Project Overview

This is a comprehensive insurance product management platform built with a microservices architecture. The system is designed to digitize and automate key insurance processes, centralize customer information, facilitate payment reconciliation, and automate report generation.

### Key Features
- Insurance product management
- Customer portfolio administration
- Payment processing and reconciliation
- Automated reports and notifications
- Security, traceability, and regulatory compliance

### Architecture
- **Architecture Style**: Microservices with Hexagonal Architecture (Ports and Adapters) and Domain-Driven Design (DDD)
- **Backend Technology**: Java 24 with Spring Boot 3.5.3
- **Build System**: Gradle
- **Database**: PostgreSQL with Redis for caching
- **Service Discovery**: Netflix Eureka
- **API Gateway**: Spring Cloud Gateway
- **Authentication**: OAuth2 with Keycloak
- **Containerization**: Docker

### Project Structure
The project is organized as a multi-module Gradle project with the following services:

1. **api-gateway** - Entry point for all client requests, handles routing, security, and cross-cutting concerns
2. **auth-service** - Authentication and authorization service using OAuth2 and JWT
3. **discovery-server** - Netflix Eureka service discovery server
4. **clients-service** - Manages client information and profiles
5. **products-service** - Handles insurance products and policies
6. **payments-service** - Processes payments and handles financial transactions
7. **news-service** - Manages news and announcements
8. **reports-service** - Generates various reports and analytics
9. **batch-processor** - Handles batch processing jobs
10. **docker** - Contains Docker Compose configuration and database initialization scripts

### Development Standards

#### Architecture Principles
- **Hexagonal Architecture**: Business logic is isolated from external frameworks, databases, and services using ports and adapters
- **Domain-Driven Design**: Clear domain modeling with entities, value objects, aggregates, and domain services
- **Decoupling**: Each service is independent with well-defined boundaries
- **Event-Driven**: Domain events are emitted for significant changes to enable eventual consistency

#### Coding Conventions
- **Java 24** with modern features and best practices
- **Lombok** annotations to reduce boilerplate code
- **Spring Boot** for dependency injection and auto-configuration
- **JPA/Hibernate** for data persistence
- **RESTful APIs** with proper HTTP status codes and error handling

#### Layer Structure (per service)
1. **Domain Layer**: Core business logic with entities, value objects, domain services, and ports
2. **Application Layer**: Use case implementations that orchestrate domain logic
3. **Infrastructure Layer**: Adapters for external systems (REST controllers, JPA repositories, HTTP clients)
4. **Configuration Layer**: Spring configuration classes and beans

### Development Workflow

#### Git Commit Guidelines
- Use imperative verbs: Add, Fix, Change, Remove, Update, Refactor
- No periods or ellipses in commit messages
- Title maximum 50 characters
- Use semantic prefixes:
  - `feat`: New features
  - `fix`: Bug fixes
  - `perf`: Performance improvements
  - `build`: Build system changes
  - `ci`: CI configuration changes
  - `docs`: Documentation changes
  - `refactor`: Code refactoring
  - `style`: Formatting changes
  - `test`: Test additions/modifications
- Include scope when applicable: `feat(auth): add login with Google`

#### Code Quality Standards
- **SOLID Principles**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **Clean Code**: Clear naming, small functions, minimal complexity
- **Design Patterns**: Strategy, Factory, Builder, Adapter, etc. when appropriate
- **Testing**: Unit and integration tests with isolated business logic
- **Exception Handling**: Clear exception hierarchies with custom exceptions
- **Security**: Strong authentication and authorization (JWT, OAuth2)

### Building and Running

#### Prerequisites
- Java 24
- Docker and Docker Compose
- PostgreSQL (via Docker)
- Redis (via Docker)
- Keycloak (via Docker)

#### Local Development Setup
1. Start the required infrastructure services:
   ```bash
   cd docker
   docker-compose up -d
   ```
2. Start individual services using Gradle:
   ```bash
   ./gradlew bootRun
   ```

#### Service Dependencies
- All services register with the discovery-server
- api-gateway routes requests to appropriate services
- auth-service handles authentication for all services
- Each service connects to its dedicated PostgreSQL database
- Redis is used for caching and session management

### Deployment
The project uses Docker Compose for local development and deployment. Each service has its own Dockerfile, and the docker directory contains the compose configuration for all infrastructure services.

### Common Development Tasks
1. **Adding a new feature**:
   - Identify the appropriate service
   - Implement domain logic following DDD principles
   - Create application service for the use case
   - Add REST endpoints in infrastructure layer
   - Create/update tests

2. **Creating a new service**:
   - Follow the existing service structure
   - Implement the hexagonal architecture layers
   - Register with Eureka discovery server
   - Configure OAuth2 resource server

3. **Database changes**:
   - Update the appropriate init script in docker/init-scripts
   - Ensure backward compatibility
   - Update entity classes accordingly