APP_NAME := Codex Usage
PRODUCT := CodexUsage
APP_BUNDLE := build/$(APP_NAME).app

.PHONY: build bundle install uninstall clean run

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp .build/release/$(PRODUCT) "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT)"
	cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --sign - "$(APP_BUNDLE)"

bundle: build

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo 'Installed "$(APP_NAME)" to /Applications/'

uninstall:
	rm -rf "/Applications/$(APP_NAME).app"
	@echo 'Uninstalled "$(APP_NAME)" from /Applications/'

clean:
	swift package clean
	rm -rf build

run: build
	open "$(APP_BUNDLE)"
