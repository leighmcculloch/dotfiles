APP_NAME = App Scheduler
PRODUCT = AppScheduler
APP_BUNDLE = build/$(APP_NAME).app

.PHONY: build install uninstall clean run test

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	swift scripts/generate-icon.swift
	cp .build/release/$(PRODUCT) "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT)"
	cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	cp build/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	codesign --force --sign - "$(APP_BUNDLE)"

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo 'Installed "$(APP_NAME).app" to /Applications/'

uninstall:
	rm -rf "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf build

run: build
	open "$(APP_BUNDLE)"

test:
	swift test
