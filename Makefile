APP_NAME     := LayoutKeeper
PROJECT      := $(APP_NAME).xcodeproj
SCHEME       := $(APP_NAME)
CONFIG       ?= Release
DERIVED      := build
APP_PATH     := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app
INSTALL_DIR  := /Applications

.PHONY: all generate build run install test test-integration clean

all: build

# Regenerate every time so new source files are always picked up.
generate:
	xcodegen generate --quiet

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -destination "platform=macOS,arch=arm64" -quiet build

run: build
	@pkill -x $(APP_NAME) || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	open $(APP_PATH)

install: build
	@pkill -x $(APP_NAME) || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(APP_PATH) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/$(APP_NAME).app

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) -destination "platform=macOS,arch=arm64" -quiet test

clean:
	rm -rf $(DERIVED) $(PROJECT)

# Runs the TIS integration tests too; briefly switches the system layout.
test-integration: generate
	TEST_RUNNER_LK_INTEGRATION=1 xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) -destination "platform=macOS,arch=arm64" test
