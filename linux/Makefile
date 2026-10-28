UUID := blackbreak@junkers4.github.io
EXTRA := pixelfont.js pixel.js copy.js scheduler.js overlay.js notice.js indicator.js callDetect.js

.PHONY: test test-detector test-headless test-all pack install
test:
	node --test test/*.test.mjs

# gjs: the call detector (settings matrix, snapshot, camera scan)
test-detector:
	LD_LIBRARY_PATH=/usr/lib/gnome-shell GI_TYPELIB_PATH=/usr/lib/gnome-shell gjs -m test/detector.test.js

# two isolated headless GNOME Shell sessions driven from outside (about 6 minutes)
test-headless:
	./test/headless.sh

test-all: test test-detector test-headless

VERSION ?= 0.0.0-dev
ZIP := dist/blackbreak-linux-gnome-v$(VERSION).zip

pack:
	rm -rf dist build
	mkdir -p dist build
	cp -r $(UUID) build/$(UUID)
	sed -i 's|^  "name": "BlackBreak",|&\n  "version-name": "$(VERSION)",|' build/$(UUID)/metadata.json
	grep -q '"version-name": "$(VERSION)"' build/$(UUID)/metadata.json || { echo "version stamp failed"; exit 1; }
	cd build && gnome-extensions pack --force --out-dir=../dist \
		$(foreach f,$(EXTRA),--extra-source=$(f)) $(UUID)
	mv dist/$(UUID).shell-extension.zip $(ZIP)
	rm -rf build

install: pack
	gnome-extensions install --force $(ZIP)
	@echo "Installed. Log out and back in, then: gnome-extensions enable $(UUID)"
