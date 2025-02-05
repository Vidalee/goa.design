#!/usr/bin/make
#
# Makefile for goa.design
#
# Targets:
# - "depend" retrieves the Go packages needed to build and run the static site
# - "serve" starts the HTTP server that serves the site
# - "all" default target that runs all the above in order

all: depend serve

depend:
	CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest || exit 1

linkcheck:
	@cd tools/linkcheck && go install
	@(hugo serve >/dev/null &); sleep 2 && linkcheck -root http://localhost:1313 && echo No broken links!

serve:
	@hugo server --bind=0.0.0.0 --watch

clean:
	rm -rf public resources
