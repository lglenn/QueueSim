# vim: ts=2:sw=2

MODULES := state ticker
JS := $(addsuffix .js, $(addprefix js/, $(MODULES)))
COFFEE := $(addsuffix .coffee, $(addprefix src/, $(MODULES)))

js/%.js: src/%.coffee
	coffee -o js -c $<

js/index.js: $(JS)
	if [[ -f "js/index.js" ]]; then rm js/index.js; fi
	for m in $(MODULES); do echo "import \"$$m\"" >> js/index.js; done

worker.js: $(JS) js/index.js
	./node_modules/.bin/smash js/index.js > worker.js

all: worker.js

clean:
	rm -rf worker.js js/*.js
