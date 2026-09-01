APP     := TextEd.app
BINARY  := .build/release/TextEd

.PHONY: all build bundle run install clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINARY) $(APP)/Contents/MacOS/TextEd
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/Assets.car Resources/TextEd.icns $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)

# Recompile the Tahoe glass icon from the Icon Composer document
# (requires Xcode 26+; artifacts are checked in, so only run after
# editing Resources/TextEd.icon).
icon:
	xcrun actool Resources/TextEd.icon --compile Resources \
		--platform macosx --minimum-deployment-target 26.0 \
		--app-icon TextEd --include-all-app-icons \
		--output-partial-info-plist /dev/null \
		--output-format human-readable-text --notices --warnings --errors

run: bundle
	open $(APP)

# Install to /Applications and stamp the custom Finder icon (the Get Info
# paste trick, scripted) — Tahoe renders custom Finder icons bare instead
# of boxing them, and a plain copy would lose the stamped metadata.
install: bundle
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/$(APP)
	swift Scripts/set-finder-icon.swift Resources/FinderIcon.icns /Applications/$(APP)

clean:
	rm -rf .build $(APP)
