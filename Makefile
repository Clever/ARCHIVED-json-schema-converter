# usage:
# `make build` or `make` compiles src/*.coffee to lib/*.js (for all changed src/*.coffee)
# `make lib/x.js` compiles just that file (`src/x.coffee`) to lib
# `make test` runs all the tests
# `make test/<test basename, aka mongoose>` runs just that test
.PHONY: clean build test test-cov publish

TESTS=$(shell cd test && ls *.coffee | sed s/\.coffee$$//)
LIBS=$(shell find . -regex "^./src\/.*\.coffee\$$" | sed s/\.coffee$$/\.js/ | sed s/src/lib/)

all: clean build test test-cov

clean:
	rm -rf lib
	rm -f coverage.html

build: $(LIBS)

lib/%.js : src/%.coffee
	node_modules/coffee-script/bin/coffee --bare -c -o $(@D) $(patsubst lib/%,src/%,$(patsubst %.js,%.coffee,$@))

test: $(TESTS)

$(TESTS):
	DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha -r coffee-errors --bail --compilers coffee:coffee-script test/$@.coffee

test-cov:
	COVERAGE=true ./node_modules/mocha/bin/mocha -r register-handlers.js --compilers coffee:coffee-script -R html-cov test > coverage.html
	open coverage.html

publish: clean build test
	$(eval VERSION := $(shell grep version package.json | sed -ne 's/^[ ]*"version":[ ]*"\([0-9\.]*\)",/\1/p';))
		@echo \'$(VERSION)\'
		$(eval REPLY := $(shell read -p "Publish and tag as $(VERSION)? " -n 1 -r; echo $$REPLY))
		@echo \'$(REPLY)\'
		@if [[ $(REPLY) =~ ^[Yy]$$ ]]; then \
				npm publish; \
				git tag -a v$(VERSION) -m "version $(VERSION)"; \
				git push --tags; \
		fi
