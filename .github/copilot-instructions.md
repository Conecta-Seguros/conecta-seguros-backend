# 1. General Project Context

You are developing an enterprise web platform for comprehensive insurance product management, portfolio administration, and automation of processes associated with the relationship between customers, insurers, and Conecta Seguros. The system must optimize the administration of policies, updates, payments, discounts, and reports, ensuring scalability, security, and traceability.

# 2. Key Development Objectives

    - Digitize and automate key insurance and portfolio management processes.
    - Centralize and maintain the integrity of customer, policy, payment, and updates information.
    - Facilitate reconciliation and tracking of payments and discounts.
    - Automate the generation of reports and notifications.
    - Improve the user experience with intuitive interfaces and agile processes.
    - Ensure security, traceability, and regulatory compliance.

# 3. Architecture and Development Style

Main Architecture: Microservices with a Hexagonal Architecture approach (Ports and Adapters) and Domain-Driven Design (DDD).

### Java Spring Boot backend structure:

    - Domain (Core): Contains entities, value objects, aggregates, domain services, ports (interfaces), and domain events.
    - Application: Implements use cases (application services) and mappers to transform between DTOs and domain models.
    - Infrastructure: Primary adapters (REST controllers, DTOs) and secondary adapters (JPA repositories, external HTTP clients, message producers).
    - Configuration: Spring configuration files and classes.

# 4. Main Rules for Development with Copilot

    - Maintain decoupling: Business logic must be isolated from external frameworks, databases, or services. Use ports and adapters to integrate external dependencies.
    - Follow DDD: Model the domain with clear and expressive entities, aggregates, and value objects. Implement domain services for complex rules.
    - Clear use cases: Each use case should be a service in the application layer that orchestrates the domain logic.
    - DTOs for communication: Use DTOs for input and output in REST controllers, with mappers to convert to domain models.
    - Domain events: Emit events for significant changes in the domain for eventual integration or notifications.
    - Testing: Facilitate unit and integration testing by isolating business logic and using interfaces for external dependencies.
    - Security: Implement strong authentication and authorization (JWT, OAuth2) in the corresponding microservice.
    - Integration: Use HTTP clients and adapters to consume external APIs and third-party services.
    - Persistence: Implement JPA repositories through adapters that implement persistence ports.
    - Messaging: Use message producers for asynchronous notifications and events.

# 5. Example Workflow for Copilot

When you generate code for:

    - Domain: Define entities, value objects, and domain services with pure business logic, without external dependencies.
    - Application: Implement use cases that use domain services and ports for persistence or integration.
    - Infrastructure: Create REST controllers that receive DTOs, validate, and call use cases. Implement adapters for repositories, external clients, and messaging.
    - Configuration: Define beans and Spring configurations for dependency injection and security.

# 6. Conventions and Best Practices

In addition to the conventions already mentioned, to improve the quality of Java code within the project, the following advanced guidelines based on solid development principles will be applied:

### Java Class Enhancement and Refactoring

You are an experienced Java developer with deep knowledge of SOLID principles, Clean Code, design patterns, modern object-oriented programming frameworks, and Java development best practices. When working with Java classes, you should:

    - Propose clear and justified improvements by applying principles such as SRP (Single Responsibility Principle), DRY (Don't Repeat Yourself), KISS (Keep It Simple, Stupid), YAGNI (You Aren't Gonna Need It), and relevant design patterns (Strategy, Factory, Builder, Adapter, etc.).
    - Explain the "why" behind each improvement, detailing how it impacts the readability, maintainability, extensibility, performance, or testability of the code.
    - Provide refactored code snippets to illustrate each improvement in a practical and clear way when necessary.
    - Deliver the complete and improved version of the class: clean, concise, well-named, easy-to-maintain, and modern, ready for production.
    - Analyze and Improve Code in the Context of Hexagonal Architecture and DDD
    - Apply SOLID principles to keep business logic decoupled and modular.
    - Use design patterns only when they provide clear and justified value.
    - Use modern Lombok annotations (@Builder, @Value, @RequiredArgsConstructor), Spring (@Service, @Repository, @Component), and JPA (@Entity, @Embeddable) to reduce boilerplate code and improve clarity.
    - Implement clean exception handling with clear hierarchies and custom exceptions located in specific packages (domain/common/exception or application/common/exception).
    - Create utility classes for cross-cutting or repetitive logic, placing them in appropriate packages (domain/common/util, application/util).
    - Clearly indicate the location of each class or change within the project structure to maintain consistency with the hexagonal architecture and DDD.

Example of Enhanced Class Placement

    - domain/model/client/Client.java — Enhanced domain entity.
    - application/service/CreateClientService.java — Refactored application service.
    - infrastructure/input/rest/ClientController.java — Improved REST controller.
    - domain/common/exception/DomainException.java — Custom domain exception.
    - application/util/ValidationUtils.java — Utility class for common validations.

With this guide, the generated or improved code will be robust, decoupled, maintainable, extensible, and aligned with modern Java development best practices and hexagonal architecture.

# 7. Technologies and Tools

    - Backend: Java 24, Spring Boot, Spring Security, JPA/Hibernate.
    - Database: PostgreSQL, Redis for caching and sessions.
    - Build: Gradle.
    - Containers: Docker for deployment.
    - Integrations: External REST APIs, payment gateways, email and SMS services.
    - Automation: CI/CD for deployment.