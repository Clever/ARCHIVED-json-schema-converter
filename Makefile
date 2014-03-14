# usage:
# `make` or `make test` runs all the tests
# `make successful_run` runs just that test
.PHONY: test clean test-cov

TESTS=$(shell cd test && ls *.coffee | sed s/\.coffee$$// | grep -v migration)

all: test

test: $(TESTS)

$(TESTS):
	DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha -r coffee-errors --ignore-leaks --bail --timeout 180000 --compilers coffee:coffee-script test/$@.coffee

clean:
	rm -rf lib lib-cov

test-cov:
	rm -rf lib lib-cov
	./node_modules/coffee-script/bin/coffee -c -o lib src
	jscoverage lib lib-cov
	DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha -R html-cov --timeout 60000 test/ | tee coverage.html
	open coverage.html
