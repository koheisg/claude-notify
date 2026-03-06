APP_NAME    := ClaudeNotify
BUILD_DIR   := build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := $(HOME)/.claude/hooks
SETTINGS    := $(HOME)/.claude/settings.json

.PHONY: build install uninstall clean

build: $(APP_BUNDLE)

$(APP_BUNDLE): src/main.swift resources/Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	swiftc -framework Cocoa -framework UserNotifications \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) src/main.swift
	cp resources/Info.plist $(APP_BUNDLE)/Contents/
	codesign --force --sign - $(APP_BUNDLE)
	@echo "Build complete: $(APP_BUNDLE)"

install: build
	@mkdir -p $(INSTALL_DIR)
	@# Stop existing instance
	@pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@sleep 1
	@# Copy app and hooks
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	cp hooks/save-tmux-pane.sh $(INSTALL_DIR)/
	cp hooks/notify-on-stop.sh $(INSTALL_DIR)/
	chmod +x $(INSTALL_DIR)/save-tmux-pane.sh $(INSTALL_DIR)/notify-on-stop.sh
	@# Merge hooks into settings.json
	@/usr/bin/python3 scripts/merge-settings.py
	@# Register as login item
	@osascript -e 'tell application "System Events" to make login item at end with properties {path:"$(INSTALL_DIR)/$(APP_NAME).app", hidden:true}' 2>/dev/null || true
	@# Launch
	open $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Installed to $(INSTALL_DIR)"

uninstall:
	@pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@sleep 1
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	rm -f $(INSTALL_DIR)/save-tmux-pane.sh
	rm -f $(INSTALL_DIR)/notify-on-stop.sh
	@# Remove login item
	@osascript -e 'tell application "System Events" to delete login item "$(APP_NAME)"' 2>/dev/null || true
	@echo "Uninstalled. Note: hooks entries in settings.json were not removed."

clean:
	rm -rf $(BUILD_DIR)
