.PHONY: all clean test

all: clean module.js

module.js: module.coffee
	echo "compiling module.coffee to module.js"
	coffee -c module.coffee

clean:
	@if [ -f module.js ]; then \
		echo "cleaning existing module.js"; \
		rm -f module.js; \
	fi

test: all
	echo "running tests"
	npx mocha test.js
