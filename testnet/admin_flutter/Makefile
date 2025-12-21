.PHONY: help web macos build clean gen watch-web watch-macos

help:
	@echo "Available commands:"
	@echo "  make web          - Run Flutter web (chrome)"
	@echo "  make macos        - Run Flutter macOS"
	@echo "  make watch-web    - Run web with auto hot reload"
	@echo "  make watch-macos  - Run macOS with auto hot reload"
	@echo "  make build        - Build web release"
	@echo "  make gen          - Run build_runner"
	@echo "  make clean        - Clean all build artifacts"

# Run Flutter
web:
	cd apps/admin && flutter run -d chrome

macos:
	cd apps/admin && flutter run -d macos

# Run with auto hot reload (requires: brew install entr)
watch-web:
	./scripts/watch.sh chrome

watch-macos:
	./scripts/watch.sh macos

# Build
build:
	cd apps/admin && flutter build web --release

# Code generation
gen:
	flutter pub run build_runner build --delete-conflicting-outputs

# Clean
clean:
	flutter clean
	cd apps/admin && flutter clean
	find . -name "*.g.dart" -delete
	find . -name "*.freezed.dart" -delete
