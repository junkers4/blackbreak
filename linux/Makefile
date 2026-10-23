UUID := blackbreak@junkers4.github.io
EXTRA := scheduler.js overlay.js notice.js indicator.js callDetect.js

.PHONY: test pack install
test:
	node --test test/*.test.mjs

VERSION ?= 0.0.0-dev
ZIP := dist/blackbreak-linux-gnome-v$(VERSION).zip

pack:
	rm -rf dist build
	mkdir -p dist build
	cp -r $(UUID) build/$(UUID)
	sed -i 's|^  "name": "BlackBreak",|&\n  "version-name": "$(VERSION)",|' build/$(UUID)/metadata.json
	cd build && gnome-extensions pack --force --out-dir=../dist \
		$(foreach f,$(EXTRA),--extra-source=$(f)) $(UUID)
	mv dist/$(UUID).shell-extension.zip $(ZIP)
	rm -rf build

install: pack
	gnome-extensions install --force $(ZIP)
	@echo "Installed. Log out and back in, then: gnome-extensions enable $(UUID)"
