PKG_ID := $(shell yq e ".id" manifest.yaml)
PKG_VERSION := $(shell yq e ".version" manifest.yaml)
TS_FILES := $(shell find ./ -name \*.ts)
$(shell rm epic*.tar.* && rm sha256sum*.*)
$(shell wget https://github.com/EpicCash/epic/releases/download/v3.4.0/epic-startos-3.4.0-aarch64.tar.gz)
$(shell wget https://github.com/EpicCash/epic/releases/download/v3.4.0/sha256sum-epic-startos-3.4.0-aarch64.txt)
$(shell tar -zxf epic-startos-3.4.0-aarch64.tar.gz)
$(shell wget https://github.com/EpicCash/epic/releases/download/v3.4.0/epic-startos-3.4.0-amd64.tar.gz)
$(shell wget https://github.com/EpicCash/epic/releases/download/v3.4.0/sha256sum-epic-startos-3.4.0-amd64.txt)
$(shell tar -zxf epic-startos-3.4.0-amd64.tar.gz)
valid1 := $(shell sha256sum -c sha256sum-epic-startos-3.4.0-amd64.txt)
valid2 := $(shell sha256sum -c sha256sum-epic-startos-3.4.0-aarch64.txt)

# delete the target of a rule if it has changed and its recipe exits with a nonzero exit status
.DELETE_ON_ERROR:

all: verify

verify: $(PKG_ID).s9pk
	@embassy-sdk verify s9pk $(PKG_ID).s9pk
	@echo " Done!"
	@echo "   Filesize: $(shell du -h $(PKG_ID).s9pk) is ready"

install:
ifeq (,$(wildcard ~/.embassy/config.yaml))
	@echo; echo "You must define \"host: http://embassy-server-name.local\" in ~/.embassy/config.yaml config file first"; echo
else
	embassy-cli package install $(PKG_ID).s9pk
endif

clean:
	rm -rf docker-images
	rm -f image.tar
	rm -f $(PKG_ID).s9pk
	rm -f scripts/*.js

scripts/embassy.js: $(TS_FILES)
	deno bundle scripts/embassy.ts scripts/embassy.js

docker-images/aarch64.tar: Dockerfile ./foundation.json ./epic-server.toml docker_entrypoint.sh epic-node-aarch64
ifeq ($(findstring FAILED,$(valid2)),FAILED)
	@echo "sha256sum Validation Failed for epic-node-aarch64 binary"; exit 1
endif
ifeq ($(ARCH),x86_64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --build-arg ARCH=aarch64 --platform=linux/arm64 -o type=docker,dest=docker-images/aarch64.tar .
endif

docker-images/x86_64.tar: Dockerfile ./foundation.json ./epic-server.toml docker_entrypoint.sh epic-node-x86_64
ifeq ($(findstring FAILED,$(valid1)),FAILED)
	@echo "sha256sum Validation Failed for epic-node-x86_64 binary"; exit 1
endif
ifeq ($(ARCH),aarch64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --build-arg ARCH=x86_64 --platform=linux/amd64 -o type=docker,dest=docker-images/x86_64.tar .
endif

$(PKG_ID).s9pk: manifest.yaml instructions.md icon.png LICENSE scripts/embassy.js docker-images/aarch64.tar docker-images/x86_64.tar
ifeq ($(ARCH),aarch64)
	@echo "embassy-sdk: Preparing aarch64 package ..."
else ifeq ($(ARCH),x86_64)
	@echo "embassy-sdk: Preparing x86_64 package ..."
else
	@echo "embassy-sdk: Preparing Universal Package ..."
endif
	@embassy-sdk pack
