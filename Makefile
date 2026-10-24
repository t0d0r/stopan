# Standard targets for every project under AI/ (see ../AGENTS.md).

.DEFAULT_GOAL := help

IMAGE ?= stopan:latest

.PHONY: help ruby deps build test lint audit check run demo clean docker-build docker-up docker-down docker-logs

help: ## list the targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-14s %s\n", $$1, $$2}'

ruby: ## check that Ruby 4 is first on PATH (macOS ships Ruby 2.6)
	@ruby -e 'exit(RUBY_VERSION.to_i >= 4 ? 0 : 1)' || { echo "Ruby $$(ruby -e 'print RUBY_VERSION') found; Stopan needs Ruby 4 (.ruby-version). With Homebrew: export PATH=/opt/homebrew/opt/ruby/bin:\$$PATH"; exit 1; }

deps: ruby ## install gems into vendor/bundle (if missing)
	@bundle config set --local path vendor/bundle
	@bundle check >/dev/null || bundle install

build: deps ## install gems and create or migrate the development database
	bin/rails db:prepare

test: deps ## run all tests
	bin/rails test

lint: deps ## style check (rubocop) and security static analysis (brakeman)
	bin/rubocop
	bin/brakeman --no-pager --quiet

audit: deps ## check gems for known vulnerabilities (downloads the advisory database)
	bin/bundler-audit check --update

check: lint test ## lint and test; must pass before a commit

run: build ## build, create the admin user from .env if missing, start http://localhost:3000
	@bin/setup-env
	@set -a; . ./.env; set +a; bin/rails db:seed && exec bin/rails server

demo: build ## add example organizations, users and tickets (development only; needs DEMO_PASSWORD)
	@test -n "$(DEMO_PASSWORD)" || { echo "DEMO_PASSWORD is not set, e.g. DEMO_PASSWORD=choose-one make demo"; exit 1; }
	bin/rails stopan:demo

clean: ## remove caches, logs, compiled assets and test uploads (keeps databases in storage/)
	rm -rf tmp/cache tmp/storage/* public/assets
	rm -f log/*.log

docker-build: ## build the production Docker image
	docker build -t $(IMAGE) .

docker-up: ## build and start the app with docker compose on http://localhost:3000
	@bin/setup-env
	docker compose up -d --build

docker-down: ## stop the docker compose app (data stays in the storage volume)
	docker compose down

docker-logs: ## follow the docker compose app logs
	docker compose logs -f web
