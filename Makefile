SHELL := /bin/bash
.DEFAULT_GOAL := help

IMAGE  ?=
NAME   ?=
ROOTFS ?=
VCPUS  ?=
MEM    ?=

.PHONY: help install uninstall check kernel kernel-build net net-down rootfs run stop list clean distclean lint

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install Firecracker + jailer (pinned in config/versions.env)
	host/install.sh

uninstall: ## Remove Firecracker + jailer
	host/uninstall.sh

check: ## Check the host: /dev/kvm, permissions, tools
	host/check.sh

kernel: ## Fetch a prebuilt guest kernel into build/vmlinux
	kernel/fetch.sh

kernel-build: ## Build the guest kernel yourself (optional)
	kernel/build.sh

net: ## Bridge + NAT for microVMs
	net/setup.sh

net-down: ## Remove bridge, taps and NAT rules
	net/teardown.sh

rootfs: ## Container image -> ext4: make rootfs IMAGE=nginx:alpine [ROOTFS=nginx]
	@test -n "$(IMAGE)" || { echo "usage: make rootfs IMAGE=<image> [ROOTFS=<name>]"; exit 2; }
	rootfs/from-oci.sh "$(IMAGE)" $(ROOTFS)

run: ## Start a microVM: make run NAME=web1 ROOTFS=nginx [VCPUS=1 MEM=256]
	@test -n "$(NAME)" -a -n "$(ROOTFS)" || { echo "usage: make run NAME=<vm> ROOTFS=<rootfs>"; exit 2; }
	vm/run.sh "$(NAME)" "$(ROOTFS)" $(VCPUS) $(MEM)

stop: ## Stop a microVM: make stop NAME=web1
	@test -n "$(NAME)" || { echo "usage: make stop NAME=<vm>"; exit 2; }
	vm/stop.sh "$(NAME)"

list: ## List microVMs
	@vm/list.sh

clean: ## Stop all microVMs, delete build/ and run/
	@for d in run/*/; do [ -d "$$d" ] && vm/stop.sh "$$(basename "$$d")" || true; done
	rm -rf build run

distclean: clean net-down ## clean + remove host networking

lint: ## shellcheck, go vet, markdownlint (whatever is installed)
	shellcheck -x lib/*.sh host/*.sh kernel/*.sh rootfs/*.sh net/*.sh vm/*.sh rootfs/init/fc-init
	cd orchestrator && go vet ./...
	@command -v markdownlint-cli2 >/dev/null && markdownlint-cli2 "**/*.md" || echo "markdownlint-cli2 not installed, skipping"
