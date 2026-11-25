SHELL := /bin/bash
SCRIPTS := xray/rootfs/usr/local/bin/xray-render xray/rootfs/etc/s6-overlay/s6-rc.d/xray/run \
	xray/rootfs/etc/s6-overlay/s6-rc.d/xray/finish tests/e2e.sh

.PHONY: check lint test
check: lint test

lint:
	mise exec -- shellcheck $(SCRIPTS)
	mise exec -- shfmt -d $(SCRIPTS)
	mise exec -- gitleaks dir --redact --no-banner --config .gitleaks.toml .
	mise exec -- yamllint -d '{extends: default, rules: {document-start: disable, line-length: {max: 100}}}' .

# Needs Docker. Builds the image and checks the tunnel and the local network block.
test:
	tests/e2e.sh
