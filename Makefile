APP_NAME     := LayoutKeeper
PROJECT      := $(APP_NAME).xcodeproj
SCHEME       := $(APP_NAME)
CONFIG       ?= Release
DERIVED      := build
APP_PATH     := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app
INSTALL_DIR  := /Applications

.PHONY: all generate build run install test clean

all: build

generate: $(PROJECT)

$(PROJECT): project.yml
	xcodegen generate

build: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -destination "platform=macOS,arch=arm64" -quiet build

run: build
	-pkill -x $(APP_NAME)
	open $(APP_PATH)

install: build
	-pkill -x $(APP_NAME)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(APP_PATH) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/$(APP_NAME).app

test: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) -destination "platform=macOS,arch=arm64" -quiet test

clean:
	rm -rf $(DERIVED) $(PROJECT)
