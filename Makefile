.PHONY: app build clean project run test

build:
	./scripts/build.sh

test:
	./scripts/test.sh

run: build
	open .build/xcode/Build/Products/Debug/TokPeek.app

app:
	./scripts/package-app.sh

project:
	ruby scripts/generate-project.rb

clean:
	swift package clean
	cargo clean --manifest-path rust/Cargo.toml
