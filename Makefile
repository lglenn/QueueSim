# vim: ts=2:sw=2

MODULES := \
  state \
	ticker \
	random \
	job \
	assigner \
	worker \
	legend \
	scatterchart \
	barchart \
	timeseries \
	queuesim
JS := $(addsuffix .js, $(addprefix js/, $(MODULES)))
BOILERPLATE := js/start.js js/end.js
INDEX := js/index.js
OUTFILE := queuesim.js

all: $(OUTFILE)

node_modules: package.json
	npm install

$(BOILERPLATE): js/%.js: boilerplate/%.js
	cp $< $@

js/%.js: src/%.coffee
	coffee --bare --output js -c $<

$(INDEX): $(JS) $(BOILERPLATE)
	echo "import \"start\"" > $(INDEX)
	for m in $(MODULES); do echo "import \"$$m\"" >> $(INDEX); done
	echo "import \"end\"" >> $(INDEX)

$(OUTFILE): node_modules $(JS) $(INDEX)
	./node_modules/.bin/smash $(INDEX) > $(OUTFILE)

clean:
	rm -rf $(OUTFILE) js/*.js
