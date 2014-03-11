# usage:
# `make` or `make test` runs all the tests
# `make successful_run` runs just that test
.PHONY: test clean test-cov

TESTS=$(shell cd test && ls *.coffee | sed s/\.coffee$$// | grep -v migration)

all: test

test: $(TESTS)

$(TESTS):
	CLEVER_JOB_DATA=`pwd`/job_data DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha -r coffee-errors --ignore-leaks --bail --timeout 180000 --compilers coffee:coffee-script test/$@.coffee --watch

clean:
	rm -rf lib-js lib-js-cov

test-cov:
	rm -rf lib-js lib-js-cov
	./node_modules/coffee-script/bin/coffee -c -o lib-js lib
	jscoverage lib-js lib-js-cov
	# todo more generic non-coffee file find -exec cp
	cp lib/email/default.jade lib-js-cov/email/default.jade
	mkdir lib-js-cov/ps_md5
	cp lib/ps_md5/md5.js lib-js-cov/ps_md5/md5.js
	DEBUG=* NODE_ENV=test TEST_COV_CLEVER_DB=1 node_modules/mocha/bin/mocha -R html-cov --timeout 60000 --compilers coffee:coffee-script test/ | tee coverage.html
	open coverage.html
