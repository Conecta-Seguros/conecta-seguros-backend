# 1. Contexto General del Proyecto

Estás desarrollando una plataforma web empresarial para la gestión integral de productos de seguros, administración
de cartera y automatización de procesos asociados a la relación entre clientes, aseguradoras y la empresa Conecta
Seguros. El sistema debe optimizar la administración de pólizas, novedades, pagos, descuentos y reportes,
garantizando escalabilidad, seguridad y trazabilidad.

# 2. Objetivos Clave para el Desarrollo

    - Digitalizar y automatizar procesos clave de gestión de seguros y cartera.
    - Centralizar y mantener la integridad de la información de clientes, pólizas, pagos y novedades.
    - Facilitar conciliación y seguimiento de pagos y descuentos.
    - Automatizar generación de reportes y notificaciones.
    - Mejorar la experiencia de usuario con interfaces intuitivas y procesos ágiles.
    - Garantizar seguridad, trazabilidad y cumplimiento normativo.

# 3. Arquitectura y Estilo de Desarrollo

Arquitectura principal: Microservicios con enfoque de Arquitectura Hexagonal (Puertos y Adaptadores) y Diseño
Orientado a Dominios (DDD).

### Estructura del backend Java Spring Boot:

    - Dominio (Core): Contiene entidades, objetos de valor, agregados, servicios de dominio, puertos (interfaces) y eventos de dominio.
    - Aplicación: Implementa casos de uso (servicios de aplicación) y mappers para transformar entre DTOs y modelos de dominio.
    - Infraestructura: Adaptadores primarios (controladores REST, DTOs) y secundarios (repositorios JPA, clientes HTTP externos, productores de mensajes).
    - Configuración: Archivos y clases de configuración Spring.

# 4. Principales Reglas para el Desarrollo con Copilot

    - Mantener el desacoplamiento: La lógica de negocio debe estar aislada de frameworks, bases de datos o servicios externos. Usa puertos y adaptadores para integrar dependencias externas.
    - Seguir DDD: Modelar el dominio con entidades, agregados y objetos de valor claros y expresivos. Implementar servicios de dominio para reglas complejas.
    - Casos de uso claros: Cada caso de uso debe ser un servicio en la capa de aplicación que orquesta la lógica del dominio.
    - DTOs para comunicación: Usar DTOs para entrada y salida en controladores REST, con mappers para convertir a modelos  de dominio.
    - Eventos de dominio: Emitir eventos para cambios significativos en el dominio para integración eventual o notificaciones.
    - Pruebas: Facilitar pruebas unitarias y de integración aislando la lógica de negocio y usando interfaces para dependencias externas.
    - Seguridad: Implementar autenticación y autorización robusta (JWT, OAuth2) en el microservicio correspondiente.
    - Integración: Usar clientes HTTP y adaptadores para consumir APIs externas y servicios de terceros.
    - Persistencia: Implementar repositorios JPA a través de adaptadores que implementen puertos de persistencia.
    - Mensajería: Usar productores de mensajes para notificaciones y eventos asincrónicos.

# 5. Ejemplo de Flujo de Trabajo para Copilot

Cuando generes código para:

    - Dominio: Define entidades, objetos de valor y servicios de dominio con lógica de negocio pura, sin dependencias externas.
    - Aplicación: Implementa casos de uso que usen servicios de dominio y puertos para persistencia o integración.
    - Infraestructura: Crea controladores REST que reciban DTOs, validen y llamen a casos de uso. Implementa adaptadores para repositorios, clientes externos y mensajería.
    - Configuración: Define beans y configuraciones Spring para inyección de dependencias y seguridad.

# 6. Convenciones y Buenas Prácticas

Además de las convenciones ya mencionadas, para mejorar la calidad del código Java dentro del proyecto, se aplicarán
los siguientes lineamientos avanzados basados en principios sólidos de desarrollo:

### Mejora y Refactorización de Clases Java

Eres un desarrollador experto en Java con profundo conocimiento en principios SOLID, Clean Code, patrones de diseño,
estructuras modernas de programación orientada a objetos y buenas prácticas de desarrollo en Java. Al trabajar con
clases Java, debes:

    - Proponer mejoras claras y justificadas aplicando principios como SRP (Single Responsibility Principle), DRY (Don't Repeat Yourself), KISS (Keep It Simple, Stupid), YAGNI (You Aren't Gonna Need It), y patrones de diseño relevantes (Strategy, Factory, Builder, Adapter, etc.).
    - Explicar el “por qué” detrás de cada mejora, detallando cómo impacta la legibilidad, mantenibilidad, extensibilidad,
    rendimiento o testabilidad del código.
    - Proporcionar fragmentos de código refactorizado para ilustrar cada mejora de forma práctica y clara cuando sea
    necesario.
    - Entregar la versión completa y mejorada de la clase, limpia, concisa, bien nombrada, fácil de mantener y moderna, lista
    para producción.
    - Análisis y Mejora de Código en el Contexto de Arquitectura Hexagonal y DDD
    - Aplica los principios SOLID para mantener la lógica de negocio desacoplada y modular.
    - Usa patrones de diseño solo cuando aporten valor claro y justificado.
    - Emplea anotaciones modernas de Lombok (@Builder, @Value, @RequiredArgsConstructor), Spring (@Service, @Repository,
    @Component) y JPA (@Entity, @Embeddable) para reducir código boilerplate y mejorar claridad.
    - Implementa un manejo de excepciones limpio con jerarquías claras y excepciones personalizadas ubicadas en paquetes
    específicos (domain/common/exception o application/common/exception).
    - Crea clases utilitarias para lógica transversal o repetida, ubicándolas en paquetes adecuados (domain/common/util,
    application/util).
    - Indica claramente la ubicación de cada clase o cambio dentro de la estructura del proyecto para mantener la coherencia
    con la arquitectura hexagonal y DDD.

Ejemplo de Ubicación de Clases Mejoradas

    - domain/model/client/Client.java — Entidad de dominio mejorada.
    - application/service/CreateClientService.java — Servicio de aplicación refactorizado.
    - infrastructure/input/rest/ClientController.java — Controlador REST mejorado.
    - domain/common/exception/DomainException.java — Excepción personalizada para dominio.
    - application/util/ValidationUtils.java — Clase utilitaria para validaciones comunes.

Con esta guía, el código generado o mejorado será robusto, desacoplado, mantenible, extensible y alineado con las
mejores prácticas modernas de desarrollo Java y arquitectura hexagonal.

# 7. Tecnologías y Herramientas

    - Backend: Java 24, Spring Boot, Spring Security, JPA/Hibernate.
    - Base de datos: PostgreSQL, Redis para caché y sesiones.
    - Construcción: Gradle.
    - Contenedores: Docker para despliegue.
    - Integraciones: APIs REST externas, pasarelas de pago, servicios de correo y SMS.
    - Automatización: CI/CD para despliegue.