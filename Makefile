.PHONY: all generate-java generate-typescript generate-dart \
        build-java build-typescript build-dart build-all \
        install-java install-typescript install-dart install-all \
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
build-java:
	cd codegen/output/java && mvn package -q -Dmaven.test.skip=true

build-typescript:
	cd codegen/output/typescript && npm install && npm run build

build-dart:
	cd codegen/output/dart && dart pub get

build-all: build-java build-typescript build-dart

# === Install targets (make libraries available locally) ===
install-java: build-java
	cd codegen/output/java && mvn install -q -Dmaven.test.skip=true
	@echo "Java library installed to local Maven repo (~/.m2/repository/com/coreapi/coreapi-models/1.0.0/)"

install-typescript: build-typescript
	cd codegen/output/typescript && npm link
	@echo "TypeScript library linked globally. Use 'npm link @coreapi/models' in your project."

install-dart: build-dart
	@echo "Dart library available at: $(CURDIR)/codegen/output/dart"
	@echo "Add to your pubspec.yaml:"
	@echo "  dependencies:"
	@echo "    coreapi_models:"
	@echo "      path: $(CURDIR)/codegen/output/dart"

install-all: install-java install-typescript install-dart
	@echo ""
	@echo "=== All libraries installed and available ==="
	@echo "  Java:       com.coreapi:coreapi-models:1.0.0 (in ~/.m2/repository)"
	@echo "  TypeScript: @coreapi/models (npm linked globally)"
	@echo "  Dart:       coreapi_models (path reference)"

# === Clean targets ===
clean-java:
	rm -rf codegen/output/java/target

clean-typescript:
	rm -rf codegen/output/typescript/dist codegen/output/typescript/node_modules

clean-dart:
	rm -rf codegen/output/dart/.dart_tool

clean: clean-java clean-typescript clean-dart
