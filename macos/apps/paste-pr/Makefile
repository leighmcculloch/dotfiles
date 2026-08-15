APP_NAME = Paste PR
APP_BUNDLE = build/$(APP_NAME).app

.PHONY: build install uninstall clean run

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	swift scripts/generate-icon.swift
	cp .build/release/PastePR "$(APP_BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(APP_BUNDLE)/Contents/"
	cp build/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	codesign --force --sign - "$(APP_BUNDLE)"

install: build
	cp -r "$(APP_BUNDLE)" /Applications/
	@echo 'Installed "$(APP_NAME)" to /Applications/'

uninstall:
	rm -rf "/Applications/$(APP_NAME).app"
	@echo 'Uninstalled "$(APP_NAME)" from /Applications/'

clean:
	swift package clean
	rm -rf build

run: build
	open "$(APP_BUNDLE)"
