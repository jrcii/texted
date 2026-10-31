APP     := TextEd.app
ARCH    ?= $(shell uname -m)
BINARY  := .build/$(ARCH)-apple-macosx/release/TextEd
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
DMG     := TextEd-$(VERSION)-$(ARCH).dmg
SIGN_ID ?= Developer ID Application: John Cornell (3G8Z8FVUTL)
NOTARY_PROFILE ?= texted-notary

.PHONY: all build bundle run install clean icon dmg notarize

all: bundle

build:
	swift build -c release --arch $(ARCH)

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINARY) $(APP)/Contents/MacOS/TextEd
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/Assets.car Resources/TextEd.icns Resources/Icon-LICENSE \
		$(APP)/Contents/Resources/
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

# Drag-to-install disk image for a release, one per ARCH, signed with the
# Developer ID (hardened runtime and secure timestamp, as notarization needs).
dmg: bundle
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" $(APP)
	Scripts/make-dmg.sh $(APP) $(DMG)
	codesign --force --timestamp --sign "$(SIGN_ID)" $(DMG)

# Notarize and staple the DMG. NOTARY_PROFILE is a keychain profile made once
# with `xcrun notarytool store-credentials`.
notarize: dmg
	xcrun notarytool submit $(DMG) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(DMG)

# Install to /Applications and stamp the custom Finder icon (the Get Info
# paste trick, scripted) — Tahoe renders custom Finder icons bare instead
# of boxing them, and a plain copy would lose the stamped metadata.
install: bundle
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/$(APP)
	swift Scripts/set-finder-icon.swift Resources/FinderIcon.icns /Applications/$(APP)

clean:
	rm -rf .build $(APP)
