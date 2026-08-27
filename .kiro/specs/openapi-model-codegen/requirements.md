# Requirements Document

## Introduction

A code generation project that reads the OpenAPI specification at `APISpec/OpenAPI.yaml` and generates data model classes (DTOs/schemas only) for three target platforms: Java (Maven JAR with Jackson annotations for Quarkus), TypeScript (npm package with interfaces and enums for Angular), and Dart (pub package with json_serializable for Flutter). The generation is orchestrated via shell scripts and a Makefile, using openapi-generator-cli as the generation engine. The generated outputs are packaged as publishable platform-specific libraries.

## Glossary

- **CodeGen_System**: The code generation project comprising configuration, scripts, templates, and build tooling that produces platform-specific model libraries from the OpenAPI specification
- **OpenAPI_Spec**: The OpenAPI 3.1.0 YAML file located at `APISpec/OpenAPI.yaml` that defines all schema components serving as the single source of truth for model generation
- **Generator_CLI**: The openapi-generator-cli tool used to parse the OpenAPI_Spec and produce language-specific source code
- **Java_Models**: The generated Java data model classes packaged as a Maven JAR artifact with Jackson serialization annotations
- **TypeScript_Models**: The generated TypeScript interfaces and enum definitions packaged as a publishable npm package
- **Dart_Models**: The generated Dart model classes packaged as a publishable Dart package using json_serializable for JSON serialization
- **Makefile**: The top-level orchestration file providing targets for generating, building, and packaging all three platform outputs
- **Schema**: A named type definition under `components/schemas` in the OpenAPI_Spec (approximately 45 schemas including DTOs, entities, and enums)

## Requirements

### Requirement 1: OpenAPI Specification Parsing

**User Story:** As a developer, I want the code generation system to read and parse the OpenAPI spec so that all defined schemas are available for model generation.

#### Acceptance Criteria

1. WHEN the generation process is invoked, THE CodeGen_System SHALL read the OpenAPI_Spec from the path `APISpec/OpenAPI.yaml` relative to the repository root.
2. WHEN the OpenAPI_Spec contains `$ref` references between schemas, THE CodeGen_System SHALL resolve all references and generate corresponding type relationships in the output models.
3. WHEN the OpenAPI_Spec defines enum types (AppointmentStatus, BillCategory, BillStatus, VisitStatus, VisitType), THE CodeGen_System SHALL generate dedicated enum representations in each target language.
4. WHEN the OpenAPI_Spec defines date/time schemas (Instant as `date-time`, LocalDate as `date`, LocalDateTime as `date-time`, OffsetDateTime as `date-time`, Date as `date`), THE CodeGen_System SHALL map each format to the appropriate date/time type for the target language.

### Requirement 2: Java Model Generation

**User Story:** As a backend developer, I want Java model classes generated with Jackson annotations so that the Quarkus backend can serialize and deserialize API payloads without manual model maintenance.

#### Acceptance Criteria

1. WHEN Java generation is triggered, THE CodeGen_System SHALL produce Java class files for each schema defined in the OpenAPI_Spec.
2. THE Java_Models SHALL include Jackson serialization annotations (`@JsonProperty`) on all fields.
3. WHEN a schema references another schema via `$ref`, THE Java_Models SHALL use the referenced type as the field type in the generated class.
4. WHEN a schema defines an array field, THE Java_Models SHALL represent the field as a `java.util.List` parameterized with the item type.
5. WHEN the OpenAPI_Spec defines a numeric field with format `double`, THE Java_Models SHALL use the `Double` type for that field.
6. WHEN the OpenAPI_Spec defines a numeric field with format `int32`, THE Java_Models SHALL use the `Integer` type for that field.
7. THE Java_Models SHALL be packaged as a Maven JAR artifact with a valid `pom.xml` containing group ID, artifact ID, and version suitable for publishing to a Maven repository.

### Requirement 3: TypeScript Model Generation

**User Story:** As a frontend developer, I want TypeScript interfaces and enums generated so that the Angular web application can use type-safe API models without manual synchronization.

#### Acceptance Criteria

1. WHEN TypeScript generation is triggered, THE CodeGen_System SHALL produce TypeScript interface definitions for each object schema defined in the OpenAPI_Spec.
2. WHEN the OpenAPI_Spec defines an enum type, THE TypeScript_Models SHALL produce a TypeScript `enum` or string union type representing all enum values.
3. WHEN a schema references another schema via `$ref`, THE TypeScript_Models SHALL use the referenced interface name as the property type.
4. WHEN a schema defines an array field, THE TypeScript_Models SHALL represent the field as a TypeScript array type (`Type[]` or `Array<Type>`).
5. THE TypeScript_Models SHALL be packaged with a valid `package.json` containing name, version, main entry point, and types declaration suitable for publishing to an npm registry.
6. WHEN the OpenAPI_Spec defines date/time fields (Instant, LocalDate, LocalDateTime, OffsetDateTime, Date), THE TypeScript_Models SHALL map those fields to `string` type.

### Requirement 4: Dart Model Generation

**User Story:** As a mobile developer, I want Dart model classes generated with json_serializable so that the Flutter app can parse API responses without manual model definitions.

#### Acceptance Criteria

1. WHEN Dart generation is triggered, THE CodeGen_System SHALL produce Dart class files for each schema defined in the OpenAPI_Spec.
2. THE Dart_Models SHALL include `json_serializable` annotations (`@JsonSerializable`) and generate corresponding `fromJson`/`toJson` factory methods and helpers.
3. WHEN a schema references another schema via `$ref`, THE Dart_Models SHALL use the referenced class as the field type.
4. WHEN a schema defines an array field, THE Dart_Models SHALL represent the field as a `List<Type>`.
5. THE Dart_Models SHALL be packaged with a valid `pubspec.yaml` containing name, version, and dependencies (`json_annotation`, `json_serializable`) suitable for publishing as a Dart package.
6. WHEN the OpenAPI_Spec defines a field with `additionalProperties` (e.g., `UserPreference.customSettings`), THE Dart_Models SHALL represent that field as a `Map<String, dynamic>`.

### Requirement 5: Models-Only Scope

**User Story:** As a developer, I want only data models generated without any API client or HTTP logic so that the generated packages remain lightweight and focused.

#### Acceptance Criteria

1. THE CodeGen_System SHALL generate only schema/model classes and exclude all API client code, HTTP request logic, and endpoint definitions.
2. THE CodeGen_System SHALL exclude authentication, serialization utilities, and HTTP transport layers from the generated output.
3. WHEN configuration is provided to the Generator_CLI, THE CodeGen_System SHALL use the `--global-property models` flag (or equivalent configuration) to restrict output to model classes only.

### Requirement 6: Build Orchestration

**User Story:** As a developer, I want a Makefile and shell scripts to orchestrate the generation and build process so that the workflow is repeatable and CI-friendly.

#### Acceptance Criteria

1. THE CodeGen_System SHALL provide a Makefile at the repository root with targets for generating models for each platform (Java, TypeScript, Dart).
2. THE Makefile SHALL provide a target that generates models for all three platforms in a single invocation.
3. THE Makefile SHALL provide targets for building/compiling the generated output for each platform (e.g., `mvn package` for Java, `npm run build` for TypeScript, `dart run build_runner build` for Dart).
4. THE CodeGen_System SHALL provide shell scripts that encapsulate the openapi-generator-cli invocation with platform-specific configuration.
5. WHEN a generation target is invoked, THE CodeGen_System SHALL produce deterministic output given the same OpenAPI_Spec input and generator version.
6. THE CodeGen_System SHALL provide a `clean` target in the Makefile that removes all previously generated source files.

### Requirement 7: Generator Configuration

**User Story:** As a developer, I want per-platform generator configuration so that each output meets its target platform conventions and library requirements.

#### Acceptance Criteria

1. THE CodeGen_System SHALL maintain separate configuration files for each target platform (Java, TypeScript, Dart) specifying generator-specific options.
2. WHEN Java configuration is applied, THE CodeGen_System SHALL specify the Java package name, date library mapping, and serialization library as Jackson.
3. WHEN TypeScript configuration is applied, THE CodeGen_System SHALL specify the npm package name and configure enum generation style.
4. WHEN Dart configuration is applied, THE CodeGen_System SHALL specify the Dart package name and configure json_serializable as the serialization approach.
5. THE CodeGen_System SHALL store generator configuration files within the repository under a dedicated directory (e.g., `codegen/configs/`).

### Requirement 8: Output Directory Structure

**User Story:** As a developer, I want generated code organized in a predictable directory structure so that build tools and CI pipelines can locate artifacts reliably.

#### Acceptance Criteria

1. THE CodeGen_System SHALL output generated Java source files to a dedicated directory (e.g., `codegen/output/java/`).
2. THE CodeGen_System SHALL output generated TypeScript source files to a dedicated directory (e.g., `codegen/output/typescript/`).
3. THE CodeGen_System SHALL output generated Dart source files to a dedicated directory (e.g., `codegen/output/dart/`).
4. WHEN the generation process completes, THE CodeGen_System SHALL produce a self-contained package structure in each output directory that can be built independently.
5. THE CodeGen_System SHALL store shell scripts and configuration under a `codegen/` directory at the repository root.

### Requirement 9: Error Handling

**User Story:** As a developer, I want clear error reporting when code generation fails so that issues can be diagnosed quickly.

#### Acceptance Criteria

1. IF the OpenAPI_Spec file is not found at the expected path, THEN THE CodeGen_System SHALL exit with a non-zero exit code and print an error message indicating the missing file path.
2. IF the Generator_CLI is not installed or not found on the system PATH, THEN THE CodeGen_System SHALL exit with a non-zero exit code and print an error message indicating the missing dependency.
3. IF the Generator_CLI encounters a parse error in the OpenAPI_Spec, THEN THE CodeGen_System SHALL propagate the generator error output and exit with a non-zero exit code.
4. IF a platform build step fails (Maven, npm, or Dart), THEN THE CodeGen_System SHALL exit with a non-zero exit code and preserve the error output for diagnosis.
