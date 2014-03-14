# usage:
# `make` or `make test` runs all the tests
# `make <test basename, aka json_schema>` runs just that test
.PHONY: test clean test-cov

TESTS=$(shell cd test && ls *.coffee | sed s/\.coffee$$//)

all: test

test: $(TESTS)

$(TESTS):
	DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha -r coffee-errors --bail --compilers coffee:coffee-script test/$@.coffee

clean:
	rm -rf lib

test-cov:
	rm -rf lib
	COVERAGE=true ./node_modules/mocha/bin/mocha -r register-handlers.js --compilers coffee:coffee-script -R html-cov test > coverage.html
	open coverage.html
