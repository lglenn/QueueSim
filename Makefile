# vim: ts=2:sw=2

%.js: %.coffee
	coffee -c $<

all: worker.js
