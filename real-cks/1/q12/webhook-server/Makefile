REGISTRY  ?= docker.io/truebad0ur
IMAGE     ?= image-policy-webhook
TAG       ?= latest
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER   ?= multiarch-builder

.PHONY: build push load

build:
	docker buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORMS) \
		--tag $(REGISTRY)/$(IMAGE):$(TAG) \
		--push \
		.

# Single-arch local load (buildx can't --load multi-arch)
load:
	docker buildx build \
		--builder $(BUILDER) \
		--platform linux/amd64 \
		--tag $(REGISTRY)/$(IMAGE):$(TAG) \
		--load \
		.
