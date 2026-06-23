RUBY_RUNNER ?= mise exec ruby@3.4.9 --

.PHONY: install build serve

install:
	$(RUBY_RUNNER) bundle install

build:
	$(RUBY_RUNNER) bundle exec jekyll build

serve:
	$(RUBY_RUNNER) bundle exec jekyll serve
