# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Conecta Seguros Backend** platform - a comprehensive insurance product management system built with a microservices architecture. The platform digitizes and automates insurance processes, centralizes customer and policy information, facilitates payment reconciliation, and automates report generation with regulatory compliance.

**Tech Stack:** Java 24/25, Spring Boot 3.5.x, Spring Cloud 2025.0.0, Gradle, PostgreSQL (per-service databases), Redis (caching), Netflix Eureka (service discovery), OAuth2/Keycloak (authentication), Docker

## Repository Structure

This is a **Git submodules-based monorepo**. Each service is an independent Git repository (submodule) with its own codebase, build configuration, and deployment pipeline.

### Microservices

1. **api-gateway** (port 8080) - Spring Cloud Gateway for routing, security, and cross-cutting concerns
2. **discovery-server** (port 8761) - Netflix Eureka service registry
3. **clients-service** (port 8032) - Client/insured persons management (8 bounded contexts)
4. **products-service** (port 8033) - Insurance products, plans, policies, customer-product relationships
5. **payments-service** - Payment processing and financial transactions
6. **news-service** - News and announcements management
7. **reports-service** - Report generation and analytics
8. **batch-processor** - Batch processing jobs

### Infrastructure

- **docker/** - Docker Compose configuration and database initialization scripts
- **create-entity.ps1** - PowerShell script to scaffold hexagonal architecture structure for new entities

## Essential Commands

### Working with Submodules

```bash
# Clone repository with all submodules
git clone --recurse-submodules https://github.com/Conecta-Seguros/conecta-seguros-backend.git

# Initialize submodules in existing clone
git submodule update --init --recursive

# Pull latest changes from all submodules
git submodule update --remote --merge

# Check status of all submodules
git submodule status

# Update specific submodule to latest develop branch
cd <service-name>
git checkout develop
git pull origin develop
cd ..
git add <service-name>
git commit -m "chore(submodules): update <service-name> to latest"
```

### Running Infrastructure Services

```bash
# Start all infrastructure services (databases, Redis, Keycloak)
cd docker
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### Building and Running Individual Services

Each service is an independent Gradle project. Navigate to the service directory first:

```bash
# Build a service
cd <service-name>
./gradlew build          # Unix/Mac
gradlew.bat build        # Windows

# Run a service (with hot-reload)
./gradlew bootRun        # Unix/Mac
gradlew.bat bootRun      # Windows

# Create executable JAR
./gradlew bootJar        # Unix/Mac
gradlew.bat bootJar      # Windows

# Run tests
./gradlew test

# Format code (Google Java Format)
./gradlew spotlessApply

# Run checkstyle
./gradlew checkstyleMain
```

### Creating New Entities

Use the PowerShell script to scaffold hexagonal architecture structure:

```powershell
# From repository root
.\create-entity.ps1 -EntityName "nombre_entidad"
```

This creates the full hexagonal architecture structure with domain, application, and infrastructure layers.

## Architecture

### Microservices Design

- **Architecture Style:** Hexagonal Architecture (Ports & Adapters) with Domain-Driven Design (DDD)
- **Communication:** Synchronous via HTTP/REST (Spring Cloud OpenFeign), with OAuth2 token propagation
- **Service Discovery:** Netflix Eureka - all services register on startup
- **API Gateway:** Single entry point (api-gateway) routes to services, handles cross-cutting concerns
- **Authentication:** OAuth2 Resource Server pattern - JWT tokens from Keycloak validated by each service
- **Database per Service:** Each service has its own PostgreSQL database (database-per-service pattern)
- **Caching:** Redis shared across services for distributed caching

### Hexagonal Architecture Pattern (per service)

```
service/
├── domain/              # Core business logic (no external dependencies)
│   ├── model/           # Entities, Value Objects, Aggregates (immutable, rich domain models)
│   ├── port/
│   │   ├── input/       # Use case interfaces (driving ports)
│   │   └── output/      # Repository/External service ports (driven ports)
│   ├── criteria/        # Search criteria objects
│   └── exceptions/      # Domain-specific exceptions
├── application/         # Use case orchestration
│   ├── command/         # Command objects (use case inputs)
│   ├── service/         # Service implementations of use cases
│   └── mapper/          # Domain ↔ DTO mapping
└── infrastructure/      # Framework & external adapters
    ├── input/
    │   ├── rest/        # Spring REST controllers
    │   └── dto/         # Request/Response DTOs
    ├── output/
    │   ├── adapter/     # Repository/External service adapter implementations
    │   ├── entity/      # JPA entities
    │   ├── mapper/      # Domain ↔ JPA Entity mapping
    │   └── repository/  # Spring Data JPA repositories
    └── config/          # Spring configuration classes
```

### Key Architectural Principles

1. **Dependency Rule:** Dependencies flow inward: Infrastructure → Application → Domain. Domain layer has zero external dependencies.

2. **Rich Domain Models:** Entities contain business logic, validation, and behavior. Factory methods (`create()`, `reconstruct()`) and behavior methods (`activate()`, `disable()`).

3. **Value Objects:** Domain primitives wrapped in immutable value objects with validation (e.g., `ClienteCedula`, `ProductoNombre`).

4. **Ports & Adapters:**
   - Input Ports: Use case interfaces in `domain/port/input/`
   - Output Ports: Repository/service interfaces in `domain/port/output/`
   - Adapters: Implementations in `infrastructure/` layer

5. **Commands:** Use case inputs represented as command objects (e.g., `CreateClienteCommand`) in `application/command/`

6. **Mappers:** Two distinct types:
   - `PersistenceMapper`: Domain ↔ JPA Entity (in `infrastructure/output/mapper/`)
   - `ApplicationMapper`: Domain ↔ DTO (in `application/mapper/`)

7. **Specifications:** JPA dynamic queries use Specification pattern for type-safe, composable queries

### Security Architecture

- **OAuth2 + JWT:** Keycloak issues JWT tokens with realm roles
- **Resource Server:** Each service validates JWT tokens independently
- **Role Converter:** `KeycloakRealmRoleConverter` extracts roles from JWT `realm_access.roles`
- **Internal Service Auth:** Services can bypass OAuth2 by including headers:
  - `X-Request-Source: internal`
  - `X-Service-Name: <service-name>`
  - Both headers required per SecurityConfig

### Service Communication

- **Feign Clients:** Declarative HTTP clients with OpenFeign
- **OAuth2 Propagation:** `OAuth2FeignRequestInterceptor` adds JWT token + internal headers to inter-service requests
- **Resilience4j:** Circuit breaker, retry, bulkhead, and time limiter patterns
  - Circuit Breaker: 100 sliding window, 50% failure threshold, 60s open state
  - Retry: 3 attempts with exponential backoff (500ms base, 2x multiplier)
  - Bulkhead: 25 max concurrent calls
  - Time Limiter: 3s timeout per call

### Database Management

- **Flyway Migrations:** All schema changes via versioned migrations
  - Location: `src/main/resources/db/migrations/`
  - Naming: `V{number}__{description}.sql`
  - Auto-run on startup
- **JPA:** `ddl-auto=none` in production (Flyway manages schema)
- **Connection Pooling:** HikariCP (20 max connections, 5 min-idle, 60s leak detection)

### Caching Strategy

- **Redis:** Distributed cache shared across services
- **Spring Cache:** `@Cacheable`, `@CacheEvict`, `@CachePut` annotations
- **TTL:** 10 minutes (600000ms)
- **Cache Invalidation:** Clear on mutations (Create/Update/Delete)
- **Cache Keys:** Structured as `{service}:{entity}:{operation}:{id}`

### Monitoring & Observability

Each service exposes:
- **Health:** `/actuator/health` (liveness and readiness probes)
- **Info:** `/actuator/info` (application metadata)
- **Metrics:** `/actuator/metrics` (application metrics)
- **Prometheus:** `/actuator/prometheus` (Prometheus-formatted metrics)

Health check groups:
- **Liveness:** `livenessState`, `diskSpace`
- **Readiness:** `readinessState`, `db`, `redis`, `eureka`

## Development Standards

### Git Workflow

- **Main Branch:** `develop` (default branch for PRs and auto-deployment)
- **Commit Messages:** Follow conventional commits format:
  ```
  <type>(<scope>): <subject>

  Types: feat, fix, perf, build, ci, docs, refactor, style, test
  Scope: service name or component (e.g., clients, products, auth)
  Subject: Imperative mood, no period, max 50 chars

  Examples:
  feat(clients): add search by cedula endpoint
  fix(products): resolve unique constraint violation on policy number
  refactor(payments): extract payment validation to domain service
  ```

### Code Quality Standards

1. **SOLID Principles:** Strict adherence to Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion

2. **Clean Code:** Clear naming, small functions, minimal complexity, expressive domain language

3. **Design Patterns:** Use when justified - Strategy, Factory, Builder, Adapter, Specification, Repository

4. **Immutability:** Domain models and value objects are immutable. Use `with*()` methods or factory methods for modifications.

5. **Validation:**
   - Business validation: Domain layer (value objects and aggregate methods)
   - Technical validation: Infrastructure layer (DTOs with `@Valid`)

6. **Exception Hierarchy:**
   - Domain exceptions extend `DomainException`
   - Named by intent (e.g., `ClienteNotFoundException`, `ProductoAlreadyExistsException`)
   - REST exception handler maps domain exceptions to HTTP status codes

7. **Null Handling:** JetBrains `@NotNull` and `@Nullable` annotations. Value objects have `ofNullable()` for optional values.

8. **Logging:** SLF4J with Lombok's `@Slf4j`. DEBUG for operations, INFO for events, ERROR for exceptions.

### Lombok Usage

Extensive use of Lombok annotations:
- `@Slf4j` - Logging
- `@Builder` - Builder pattern
- `@Value` - Immutable value objects
- `@RequiredArgsConstructor` - Constructor injection
- `@Getter`, `@Setter` - Property access (use sparingly on domain models)

### Testing Strategy

- **Unit Tests:** Domain logic in isolation (no Spring context)
- **Integration Tests:** Application services with mocked ports
- **Controller Tests:** REST endpoints with `@WebMvcTest` or `@SpringBootTest`
- **Test Framework:** JUnit 5 with Mockito
- **Annotations:**
  - `@ExtendWith(MockitoExtension.class)` - Unit tests
  - `@SpringBootTest` with `@Transactional` - Integration tests

### API Design

RESTful APIs following pattern: `/api/v1/{service}/{entity}`

Standard operations:
- `POST /api/v1/{service}/{entity}` - Create
- `GET /api/v1/{service}/{entity}/{id}` - Get by ID
- `PUT /api/v1/{service}/{entity}/{id}` - Update
- `DELETE /api/v1/{service}/{entity}/{id}` - Delete
- `GET /api/v1/{service}/{entity}` - List all
- `GET /api/v1/{service}/{entity}/search` - Search with filters/pagination
- Status change operations (e.g., `PUT /api/v1/{service}/{entity}/activate/{id}`)

Response format:
```json
{
  "message": "Operation successful",
  "data": { ... }
}
```

Error format:
```json
{
  "message": "Error description",
  "timestamp": "2025-11-08T10:30:00Z",
  "errors": ["Detail 1", "Detail 2"]
}
```

## Common Development Tasks

### Adding a New Feature to Existing Service

1. Navigate to service directory
2. Identify appropriate bounded context
3. Create domain model (if needed) in `domain/model/`
4. Define use case interface in `domain/port/input/`
5. Create command object in `application/command/`
6. Implement service in `application/service/`
7. Create DTOs in `infrastructure/input/dto/`
8. Add REST endpoint in `infrastructure/input/rest/`
9. Create/update database migration in `src/main/resources/db/migrations/`
10. Write tests
11. Format code: `./gradlew spotlessApply`
12. Run tests: `./gradlew test`

### Creating a New Bounded Context

1. Use `.\create-entity.ps1 -EntityName "context_name"` to scaffold structure
2. Follow hexagonal architecture pattern (see existing contexts like `cliente/`, `producto/`)
3. Create domain model with entities and value objects
4. Define ports (input use cases and output repositories)
5. Implement application services
6. Create infrastructure adapters (REST controllers, JPA repositories)
7. Create Flyway migration for database schema
8. Configure beans in `infrastructure/config/` if needed

### Adding a New Microservice

1. Create new Git repository
2. Add as submodule: `git submodule add -b develop <repo-url> <service-name>`
3. Structure following hexagonal architecture (use existing services as template)
4. Configure `build.gradle.kts` with Spring Boot/Cloud dependencies
5. Implement Eureka client registration
6. Configure OAuth2 resource server
7. Add database in `docker/docker-compose.yml`
8. Create init script in `docker/init-scripts/`
9. Update api-gateway routes in `api-gateway/src/.../config/GatewayRoutesConfig.java`
10. Document in service-specific CLAUDE.md

### Working with Service Submodules

Each service has its own CLAUDE.md with service-specific guidance. When working on a specific service:

1. Navigate to service directory: `cd <service-name>`
2. Read service CLAUDE.md: `cat CLAUDE.md`
3. Follow service-specific patterns and conventions
4. Commit changes within submodule
5. Push submodule changes to its repository
6. Update parent repository reference: `git add <service-name> && git commit -m "chore(submodules): update <service-name>"`

### Database Changes

1. Create migration file: `V{next_number}__{description}.sql`
2. Place in service's `src/main/resources/db/migrations/`
3. Update JPA entity if needed
4. Update domain model and mappers
5. Test migration with `./gradlew bootRun` or `./gradlew test`
6. Ensure backward compatibility for zero-downtime deployments

## Infrastructure Configuration

### Required Environment Variables

Create `.env` file in each service directory:

```properties
# Database
DB_HOST=localhost
DB_PORT=5434          # Port varies per service (5434-5438)
DB_NAME=<service>_db
DB_USERNAME=<username>
DB_PASSWORD=<password>

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Keycloak (for docker-compose)
KEYCLOAK_ADMIN_USERNAME=admin
KEYCLOAK_ADMIN_PASSWORD=<password>
```

### Service Ports

- **api-gateway:** 8080
- **discovery-server:** 8761
- **clients-service:** 8032 (prod), dynamic (dev)
- **products-service:** 8033 (prod), dynamic (dev)
- **keycloak:** 8181
- **PostgreSQL databases:** 5434-5439 (one per service + Keycloak)
- **Redis:** 6379

### Docker Compose Services

- `clients_db` (port 5434)
- `products_db` (port 5435)
- `payments_db` (port 5436)
- `news_db` (port 5437)
- `reports_db` (port 5438)
- `keycloak_db` (port 5439)
- `redis_cache` (port 6379)
- `keycloak` (port 8181)

## CI/CD

Each service has its own GitHub Actions workflow (`.github/workflows/<service-name>.yml`):

1. **Build:** Compile and create JAR artifact (Java 25, Gradle 9.1.0)
2. **Security Scan:** Trivy vulnerability scanning
3. **Docker Build:** Push to GitHub Container Registry (ghcr.io)
4. **Deploy:** Auto-deploy to VPS when pushing to `develop` branch

Container naming: `conecta-<service-name>-service`

## API Documentation

Each service exposes Swagger UI:
- **URL:** `http://localhost:{PORT}/swagger-ui.html`
- **OpenAPI JSON:** `http://localhost:{PORT}/v3/openapi.json`

## Common Pitfalls

1. **Hexagonal Boundary Violations:** Never import infrastructure classes in domain or application layers
2. **Repository Leakage:** Repository interfaces must be in `domain/port/output/`; implementations in `infrastructure/output/adapter/`
3. **Entity Exposure:** Never return JPA entities in REST responses; always map to DTOs first
4. **Cache Invalidation:** Clear cache after mutations (Create/Update/Delete)
5. **Transaction Scope:** Services marked `@Transactional` - avoid long-running operations
6. **Submodule Commits:** Remember to commit changes both in submodule AND parent repository
7. **Service Dependencies:** Start in order: docker-compose → discovery-server → api-gateway → other services
8. **Internal Service Auth:** Both headers required: `X-Request-Source: internal` AND `X-Service-Name: <name>`
9. **Flyway Conflicts:** Never modify existing migrations; create new ones for changes
10. **Spring Cloud Versions:** Spring Boot and Spring Cloud versions are tightly coupled - update together

## Service-Specific Documentation

For detailed service-specific information, refer to each service's CLAUDE.md:
- `clients-service/CLAUDE.md` - Client management (8 bounded contexts)
- `products-service/CLAUDE.md` - Products, plans, policies, customer-product relationships
- `news-service/CLAUDE.md` - News and announcements
- (Other services have their own documentation)
