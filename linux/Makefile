UUID := blackbreak@junkers4.github.io
EXTRA := scheduler.js overlay.js notice.js indicator.js callDetect.js

.PHONY: test pack install
test:
	node --test test/*.test.mjs

pack:
	mkdir -p dist
	gnome-extensions pack --force --out-dir=dist \
		$(foreach f,$(EXTRA),--extra-source=$(f)) $(UUID)

install: pack
	gnome-extensions install --force dist/$(UUID).shell-extension.zip
	@echo "Installed. Log out and back in, then: gnome-extensions enable $(UUID)"
