APP_NAME := CodexResetBar
OLD_APP_NAME := CodexBarResetBar
CONFIGURATION ?= release
BUILD_DIR := .build/$(CONFIGURATION)
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents
MACOS := $(CONTENTS)/MacOS
RESOURCES := $(CONTENTS)/Resources
RESOURCE_BUNDLE := $(APP_NAME)_$(APP_NAME).bundle
ICON_FILE := AppIcon.icns

.PHONY: build test run app install icon clean

build:
	swift build -c $(CONFIGURATION)

test:
	swift test

run:
	swift run $(APP_NAME)

icon:
	./scripts/generate-app-icon.sh

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS)" "$(RESOURCES)"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS)/$(APP_NAME)"
	cp -R "$(BUILD_DIR)/$(RESOURCE_BUNDLE)" "$(RESOURCES)/"
	cp "Assets/$(ICON_FILE)" "$(RESOURCES)/$(ICON_FILE)"
	/usr/libexec/PlistBuddy -c "Clear dict" "$(CONTENTS)/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" "$(CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.lcc.codexresetbar" "$(CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" "$(CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$(CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$(CONTENTS)/Info.plist"

install: app
	pkill -x "$(APP_NAME)" || true
	pkill -x "$(OLD_APP_NAME)" || true
	rm -rf "/Applications/$(APP_NAME).app"
	rm -rf "/Applications/$(OLD_APP_NAME).app"
	cp -R "$(APP_DIR)" /Applications/
	open "/Applications/$(APP_NAME).app"

clean:
	rm -rf .build
