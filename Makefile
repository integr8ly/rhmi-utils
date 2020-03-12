include ./make/*.mk

.PHONY: test/lint
test/lint:
	@shellcheck scripts/ocm/*