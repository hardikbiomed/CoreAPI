# Implementation Plan: OpenAPI Model Code Generation

## Overview

Build a code generation pipeline that reads `APISpec/OpenAPI.yaml` and produces publishable model-only libraries for Java (Maven/Jackson), TypeScript (npm/Angular), and Dart (pub/json_serializable). The pipeline is orchestrated by a Makefile and per-platform shell scripts wrapping `openapi-generator-cli`.

## Tasks

- [x] 1. Set up project structure and generator configuration
  - [x] 1.1 Create directory structure and generator config files
    - Create `codegen/configs/`, `codegen/scripts/`, and `codegen/output/` directories
    - Create `codegen/configs/java.yaml` with Java generator options (Jackson, java8 date library, models-only, package `com.coreapi.models`)
    - Create `codegen/configs/typescript.yaml` with TypeScript-Angular generator options (npm name `@coreapi/models`, stringEnums, models-only)
    - Create `codegen/configs/dart.yaml` with Dart generator options (pubName `coreapi_models`, json_serializable, models-only)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 8.5_

  - [x] 1.2 Create `openapitools.json` for generator version pinning
    - Create `openapitools.json` at repo root to pin `openapi-generator-cli` version for deterministic output
    - _Requirements: 6.5_

- [x] 2. Implement generation shell scripts
  - [x] 2.1 Create Java generation script (`codegen/scripts/generate-java.sh`)
    - Validate `APISpec/OpenAPI.yaml` exists, validate `openapi-generator-cli` is on PATH
    - Invoke `openapi-generator-cli generate -c codegen/configs/java.yaml`
    - Exit with code 1 and descriptive stderr message on any failure
    - _Requirements: 1.1, 5.3, 6.4, 9.1, 9.2, 9.3_

  - [x] 2.2 Create TypeScript generation script (`codegen/scripts/generate-typescript.sh`)
    - Same validation and error handling pattern as Java script
    - Invoke `openapi-generator-cli generate -c codegen/configs/typescript.yaml`
    - _Requirements: 1.1, 5.3, 6.4, 9.1, 9.2, 9.3_

  - [x] 2.3 Create Dart generation script (`codegen/scripts/generate-dart.sh`)
    - Same validation and error handling pattern as Java and TypeScript scripts
    - Invoke `openapi-generator-cli generate -c codegen/configs/dart.yaml`
    - _Requirements: 1.1, 5.3, 6.4, 9.1, 9.2, 9.3_

- [x] 3. Implement Makefile orchestration
  - [x] 3.1 Create the Makefile with generation, build, and clean targets
    - Add `generate-java`, `generate-typescript`, `generate-dart` targets calling respective scripts
    - Add `all` target generating all three platforms
    - Add `build-java` (mvn package), `build-typescript` (npm install + npm run build), `build-dart` (dart pub get + build_runner) targets
    - Add `build-all` target building all platforms
    - Add `clean-java`, `clean-typescript`, `clean-dart`, and `clean` targets removing generated output
    - Ensure build targets depend on generation targets
    - Ensure non-zero exit codes propagate on failure
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 9.4_

- [x] 4. Checkpoint - Validate generation pipeline
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Create output package scaffolding
  - [x] 5.1 Create Java Maven package structure
    - Create `codegen/output/java/pom.xml` with groupId `com.coreapi`, artifactId `coreapi-models`, version `1.0.0`, and Jackson dependencies
    - Create source directory structure `src/main/java/com/coreapi/models/`
    - _Requirements: 2.7, 8.1, 8.4_

  - [x] 5.2 Create TypeScript npm package structure
    - Create `codegen/output/typescript/package.json` with name `@coreapi/models`, version, main, types fields
    - Create `codegen/output/typescript/tsconfig.json` for compilation
    - Create `src/` directory for generated interfaces
    - _Requirements: 3.5, 8.2, 8.4_

  - [x] 5.3 Create Dart package structure
    - Create `codegen/output/dart/pubspec.yaml` with name `coreapi_models`, version, and dependencies (json_annotation, json_serializable, build_runner)
    - Create `lib/` directory for generated models
    - _Requirements: 4.5, 8.3, 8.4_

- [x] 6. Checkpoint - Verify end-to-end generation
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Validate generated output correctness
  - [x] 7.1 Write property test for schema coverage (Property 1)
    - **Property 1: Schema Coverage**
    - Verify that every schema under `components/schemas` in OpenAPI.yaml has a corresponding generated type in each platform output
    - **Validates: Requirements 2.1, 3.1, 4.1**

  - [x] 7.2 Write property test for reference type resolution (Property 2)
    - **Property 2: Reference Type Resolution**
    - Verify that `$ref` fields are generated with the referenced type name in each platform
    - **Validates: Requirements 1.2, 2.3, 3.3, 4.3**

  - [x] 7.3 Write property test for enum value completeness (Property 3)
    - **Property 3: Enum Value Completeness**
    - Verify generated enums contain exactly all values defined in the spec
    - **Validates: Requirements 1.3, 3.2**

  - [x] 7.4 Write property test for date/time type mapping (Property 4)
    - **Property 4: Date/Time Type Mapping**
    - Verify date/date-time fields map to correct platform types
    - **Validates: Requirements 1.4, 3.6**

  - [x] 7.5 Write property test for array collection mapping (Property 5)
    - **Property 5: Array Collection Mapping**
    - Verify array fields use `List<T>`, `T[]`, or `List<T>` per platform
    - **Validates: Requirements 2.4, 3.4, 4.4**

  - [x] 7.6 Write property test for Java numeric format mapping (Property 6)
    - **Property 6: Java Numeric Format Mapping**
    - Verify `int32` → `Integer`, `int64` → `Long`, `double` → `Double` in Java output
    - **Validates: Requirements 2.5, 2.6**

  - [x] 7.7 Write property test for Jackson annotation presence (Property 7)
    - **Property 7: Jackson Annotation Presence**
    - Verify every field in generated Java classes has `@JsonProperty`
    - **Validates: Requirements 2.2**

  - [x] 7.8 Write property test for Dart serialization annotations (Property 8)
    - **Property 8: Dart Serialization Annotation Presence**
    - Verify generated Dart classes have `@JsonSerializable()`, `fromJson`, and `toJson`
    - **Validates: Requirements 4.2**

  - [x] 7.9 Write property test for Dart additionalProperties mapping (Property 9)
    - **Property 9: Dart additionalProperties Mapping**
    - Verify fields with `additionalProperties` generate `Map<String, dynamic>` in Dart
    - **Validates: Requirements 4.6**

  - [x] 7.10 Write property test for models-only output exclusion (Property 10)
    - **Property 10: Models-Only Output Exclusion**
    - Verify no generated file contains API client classes, HTTP methods, or auth logic
    - **Validates: Requirements 5.1, 5.2, 5.3**

  - [x] 7.11 Write property test for generation determinism (Property 11)
    - **Property 11: Generation Determinism**
    - Verify two consecutive generation runs produce byte-identical output
    - **Validates: Requirements 6.5**

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The generation pipeline depends on `openapi-generator-cli` being installed — scripts validate this as a prerequisite
- Package scaffolding (task 5) may be partially generated by `openapi-generator-cli` depending on generator templates; adjust or skip manual creation if the generator produces these files

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3"] },
    { "id": 2, "tasks": ["3.1"] },
    { "id": 3, "tasks": ["5.1", "5.2", "5.3"] },
    { "id": 4, "tasks": ["7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "7.10", "7.11"] }
  ]
}
```
