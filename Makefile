include Makefile.env

dev:
	@${CONTAINER_CLI} run --rm -it -v $(SRC_PATH):$(WORKDIR) ${RUBY_IMAGE} /bin/sh
prune:
	@${CONTAINER_CLI} image prune -f
clean: prune

.PHONY: dev prune clean
