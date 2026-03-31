.PHONY: generate build install run clean sim

SCHEME = Claude2xApp
PROJECT = Claude2x.xcodeproj
SIMULATOR = iPhone 16
BUILD_DIR = ./build
APP_PATH = $(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Claude2xApp.app

generate:
	xcodegen generate

sim:
	xcrun simctl create "$(SIMULATOR)" "$(SIMULATOR)" 2>/dev/null || true
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	open -a Simulator

build: generate
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR),OS=latest' \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		2>&1 | tail -20

install: build sim
	xcrun simctl install booted $(APP_PATH)

run: install
	xcrun simctl launch booted com.claude2x.notifier.ios

clean:
	rm -rf $(BUILD_DIR) $(PROJECT)
