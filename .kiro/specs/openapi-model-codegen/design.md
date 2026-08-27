# Design Document: OpenAPI Model Code Generation

## Architecture Overview

The code generation system follows a pipeline architecture: a single OpenAPI specification is parsed and funnelled through platform-specific generators to produce three independent, publishable model libraries. The pipeline is orchestrated by a Makefile and thin shell scripts wrapping `openapi-generator-cli`.

```
APISpec/OpenAPI.yaml
        │
        ▼
┌──────────────────────┐
│  codegen/scripts/    │  (shell scripts per platform)
│  codegen/configs/    │  (generator config per platform)
└──────────────────────┘
        │
        ├──► openapi-generator-cli (java)       ──► codegen/output/java/
        ├──► openapi-generator-cli (typescript) ──► codegen/output/typescript/
        └──► openapi-generator-cli (dart)       ──► codegen/output/dart/
```

Each output directory is a self-contained package that can be built and published independently.

## Directory Structure

```
CoreAPI/
├── APISpec/
│   └── OpenAPI.yaml                  # Source of truth
├── Makefile                          # Top-level orchestration
├── codegen/
│   ├── configs/
│   │   ├── java.yaml                 # openapi-generator config for Java
│   │   ├── typescript.yaml           # openapi-generator config for TypeScript
│   │   └── dart.yaml                 # openapi-generator config for Dart
│   ├── scripts/
│   │   ├── generate-java.sh
│   │   ├── generate-typescript.sh
│   │   └── generate-dart.sh
│   └── output/
│       ├── java/                     # Maven project with generated models
│       │   ├── pom.xml
│       │   └── src/main/java/...
│       ├── typescript/               # npm package with generated interfaces
│       │   ├── package.json
│       │   ├── tsconfig.json
│       │   └── src/...
│       └── dart/                     # Dart package with generated models
│           ├── pubspec.yaml
│           └── lib/...
```

## Components

### 1. Generator Configuration Files

Each platform has a YAML configuration file under `codegen/configs/` that supplies generator-specific options to `openapi-generator-cli`.

#### Java Configuration (`codegen/configs/java.yaml`)

```yaml
generatorName: java
inputSpec: APISpec/OpenAPI.yaml
outputDir: codegen/output/java
globalProperties:
  models: ""
additionalProperties:
  library: native
  serializationLibrary: jackson
  dateLibrary: java8
  modelPackage: com.coreapi.models
  artifactId: coreapi-models
  groupId: com.coreapi
  artifactVersion: 1.0.0
  hideGenerationTimestamp: true
  openApiNullable: false
  useJakartaEe: true
```

#### TypeScript Configuration (`codegen/configs/typescript.yaml`)

```yaml
generatorName: typescript-angular
inputSpec: APISpec/OpenAPI.yaml
outputDir: codegen/output/typescript
globalProperties:
  models: ""
additionalProperties:
  npmName: "@coreapi/models"
  npmVersion: 1.0.0
  stringEnums: true
  enumPropertyNaming: original
  modelPropertyNaming: original
  supportsES6: true
  withInterfaces: true
```

#### Dart Configuration (`codegen/configs/dart.yaml`)

```yaml
generatorName: dart
inputSpec: APISpec/OpenAPI.yaml
outputDir: codegen/output/dart
globalProperties:
  models: ""
additionalProperties:
  pubName: coreapi_models
  pubVersion: 1.0.0
  serializationLibrary: json_serializable
  useEnumExtension: true
```

### 2. Shell Scripts

Each script validates prerequisites, invokes the generator, and exits with meaningful error codes.

#### Common Pattern (`codegen/scripts/generate-java.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_FILE="${REPO_ROOT}/APISpec/OpenAPI.yaml"
CONFIG_FILE="${REPO_ROOT}/codegen/configs/java.yaml"

# Validate spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: OpenAPI spec not found at ${SPEC_FILE}" >&2
  exit 1
fi

# Validate openapi-generator-cli is available
if ! command -v openapi-generator-cli &>/dev/null; then
  echo "ERROR: openapi-generator-cli not found on PATH" >&2
  exit 1
fi

# Run generator
openapi-generator-cli generate -c "$CONFIG_FILE" || {
  echo "ERROR: Java model generation failed" >&2
  exit 1
}

echo "Java models generated successfully."
```

The TypeScript and Dart scripts follow the same structure with their respective config paths.

### 3. Makefile

```makefile
.PHONY: all generate-java generate-typescript generate-dart \
        build-java build-typescript build-dart \
        clean clean-java clean-typescript clean-dart

SPEC := APISpec/OpenAPI.yaml

# === Generation targets ===
all: generate-java generate-typescript generate-dart

generate-java:
	@bash codegen/scripts/generate-java.sh

generate-typescript:
	@bash codegen/scripts/generate-typescript.sh

generate-dart:
	@bash codegen/scripts/generate-dart.sh

# === Build targets ===
build-java: generate-java
	cd codegen/output/java && mvn package -q

build-typescript: generate-typescript
	cd codegen/output/typescript && npm install && npm run build

build-dart: generate-dart
	cd codegen/output/dart && dart pub get && dart run build_runner build --delete-conflicting-outputs

build-all: build-java build-typescript build-dart

# === Clean targets ===
clean-java:
	rm -rf codegen/output/java/src codegen/output/java/target

clean-typescript:
	rm -rf codegen/output/typescript/src codegen/output/typescript/dist codegen/output/typescript/node_modules

clean-dart:
	rm -rf codegen/output/dart/lib codegen/output/dart/.dart_tool

clean: clean-java clean-typescript clean-dart
```

### 4. Generated Output Structure

#### Java Maven Package

The generator produces a Maven project under `codegen/output/java/`:

```xml
<!-- pom.xml (key elements) -->
<project>
  <groupId>com.coreapi</groupId>
  <artifactId>coreapi-models</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <dependencies>
    <dependency>
      <groupId>com.fasterxml.jackson.core</groupId>
      <artifactId>jackson-annotations</artifactId>
    </dependency>
  </dependencies>
</project>
```

Generated Java classes follow this pattern:

```java
package com.coreapi.models;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public class Patient {
    @JsonProperty("internalUUID")
    private String internalUUID;

    @JsonProperty("dateOfBirth")
    private java.time.OffsetDateTime dateOfBirth;

    @JsonProperty("reports")
    private List<PatientReport> reports;

    // getters/setters...
}
```

#### TypeScript npm Package

The generator produces an npm package under `codegen/output/typescript/`:

```json
{
  "name": "@coreapi/models",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc"
  }
}
```

Generated TypeScript interfaces follow this pattern:

```typescript
export interface Patient {
  internalUUID?: string;
  dateOfBirth?: string;  // date-time fields map to string
  reports?: PatientReport[];
}

export enum AppointmentStatus {
  SCHEDULED = 'SCHEDULED',
  CONFIRMED = 'CONFIRMED',
  RESCHEDULED = 'RESCHEDULED',
  CANCELLED = 'CANCELLED',
  NO_SHOW = 'NO_SHOW',
  COMPLETED = 'COMPLETED',
  ATTENDED = 'ATTENDED'
}
```

#### Dart Package

The generator produces a Dart package under `codegen/output/dart/`:

```yaml
# pubspec.yaml
name: coreapi_models
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  json_annotation: ^4.8.0
dev_dependencies:
  json_serializable: ^6.7.0
  build_runner: ^2.4.0
```

Generated Dart classes follow this pattern:

```dart
import 'package:json_annotation/json_annotation.dart';

part 'patient.g.dart';

@JsonSerializable()
class Patient {
  final String? internalUUID;
  final DateTime? dateOfBirth;
  final List<PatientReport>? reports;

  Patient({this.internalUUID, this.dateOfBirth, this.reports});

  factory Patient.fromJson(Map<String, dynamic> json) => _$PatientFromJson(json);
  Map<String, dynamic> toJson() => _$PatientToJson(this);
}
```

## Data Model: Type Mapping Table

| OpenAPI Type/Format | Java | TypeScript | Dart |
|---|---|---|---|
| `string` | `String` | `string` | `String` |
| `integer` / `int32` | `Integer` | `number` | `int` |
| `integer` / `int64` | `Long` | `number` | `int` |
| `number` / `double` | `Double` | `number` | `double` |
| `number` (no format) | `BigDecimal` | `number` | `num` |
| `boolean` | `Boolean` | `boolean` | `bool` |
| `string` / `date` | `java.time.LocalDate` | `string` | `DateTime` |
| `string` / `date-time` | `java.time.OffsetDateTime` | `string` | `DateTime` |
| `array` of T | `List<T>` | `T[]` | `List<T>` |
| `object` with `additionalProperties` | `Map<String, Object>` | `{ [key: string]: any }` | `Map<String, dynamic>` |
| `$ref: "#/components/schemas/X"` | `X` | `X` | `X` |
| `enum` values | Java `enum` | TypeScript `enum` | Dart `enum` |

## Interfaces

### Shell Script Interface

Each generation script accepts no arguments (configuration is file-based) and communicates via:
- **Exit code 0**: Success
- **Exit code 1**: Failure (with stderr message)
- **stdout**: Progress messages
- **stderr**: Error messages

### Makefile Interface

```
make generate-java          # Generate Java models only
make generate-typescript    # Generate TypeScript models only
make generate-dart          # Generate Dart models only
make all                    # Generate all platforms
make build-java             # Generate + compile Java JAR
make build-typescript       # Generate + compile TypeScript
make build-dart             # Generate + run build_runner for Dart
make build-all              # Build all platforms
make clean                  # Remove all generated output
```

## Error Handling

| Condition | Behaviour |
|---|---|
| `APISpec/OpenAPI.yaml` missing | Script exits 1, stderr: `ERROR: OpenAPI spec not found at <path>` |
| `openapi-generator-cli` not on PATH | Script exits 1, stderr: `ERROR: openapi-generator-cli not found on PATH` |
| Generator parse error | Generator stderr is preserved, script exits 1 |
| `mvn package` failure | Make target fails with Maven output preserved |
| `npm run build` failure | Make target fails with npm output preserved |
| `dart run build_runner build` failure | Make target fails with Dart output preserved |

## Determinism

The system achieves deterministic output by:
1. Using `hideGenerationTimestamp: true` in Java config to suppress timestamps in generated files
2. Pinning the `openapi-generator-cli` version (via `openapitools.json` or explicit version flag)
3. Using fixed configuration files checked into source control
4. The `globalProperties.models` restriction ensuring only model classes are generated

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Schema Coverage

*For any* object schema defined under `components/schemas` in the OpenAPI spec, and *for any* target platform (Java, TypeScript, Dart), the code generation system SHALL produce a corresponding type definition (class or interface) in that platform's output directory.

**Validates: Requirements 2.1, 3.1, 4.1**

### Property 2: Reference Type Resolution

*For any* field in the OpenAPI spec that uses a `$ref` reference to another schema, and *for any* target platform, the generated code SHALL declare that field's type as the referenced schema's generated type name.

**Validates: Requirements 1.2, 2.3, 3.3, 4.3**

### Property 3: Enum Value Completeness

*For any* enum schema defined in the OpenAPI spec, and *for any* target platform, the generated enum representation SHALL contain exactly all values defined in the spec, with no additions or omissions.

**Validates: Requirements 1.3, 3.2**

### Property 4: Date/Time Type Mapping

*For any* field with format `date` or `date-time` in the OpenAPI spec, and *for any* target platform, the generated type SHALL match the platform's designated date/time mapping: `java.time.LocalDate`/`java.time.OffsetDateTime` for Java, `string` for TypeScript, and `DateTime` for Dart.

**Validates: Requirements 1.4, 3.6**

### Property 5: Array Collection Mapping

*For any* field defined as `type: array` with an `items` type in the OpenAPI spec, and *for any* target platform, the generated code SHALL represent that field using the platform's collection type parameterized with the item type: `List<T>` for Java, `T[]` or `Array<T>` for TypeScript, `List<T>` for Dart.

**Validates: Requirements 2.4, 3.4, 4.4**

### Property 6: Java Numeric Format Mapping

*For any* numeric field in the OpenAPI spec with an explicit format, the generated Java code SHALL use the format-specific type: `Integer` for `int32`, `Long` for `int64`, `Double` for `double`.

**Validates: Requirements 2.5, 2.6**

### Property 7: Jackson Annotation Presence

*For any* field in any generated Java model class, the field SHALL be annotated with `@JsonProperty` specifying the original OpenAPI property name.

**Validates: Requirements 2.2**

### Property 8: Dart Serialization Annotation Presence

*For any* generated Dart model class, the class SHALL be annotated with `@JsonSerializable()` and SHALL provide a `fromJson` factory constructor and a `toJson` method.

**Validates: Requirements 4.2**

### Property 9: Dart additionalProperties Mapping

*For any* field in the OpenAPI spec defined with `additionalProperties` (free-form object), the generated Dart code SHALL represent that field as `Map<String, dynamic>`.

**Validates: Requirements 4.6**

### Property 10: Models-Only Output Exclusion

*For any* file produced by the code generation system across all platforms, the file SHALL NOT contain API client classes, HTTP request methods, endpoint route definitions, or authentication logic.

**Validates: Requirements 5.1, 5.2, 5.3**

### Property 11: Generation Determinism

*For any* two consecutive invocations of the generation process with the same OpenAPI spec and generator version, the output files SHALL be byte-for-byte identical.

**Validates: Requirements 6.5**
