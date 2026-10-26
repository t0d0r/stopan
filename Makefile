# Standard targets for every project under AI/ (see ../AGENTS.md).

.DEFAULT_GOAL := help

IMAGE ?= stopan:latest

.PHONY: help ruby deps build test lint audit check secrets hooks run demo screenshots clean docker-build docker-check docker-up docker-down docker-logs deploy

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

lint: deps secrets ## style check (rubocop), security static analysis (brakeman), secret scan
	bin/rubocop
	bin/brakeman --no-pager --quiet

secrets: ## scan the git history and staged changes for secrets (gitleaks; skipped with a warning if missing)
	@if command -v gitleaks >/dev/null; then \
	  gitleaks git --redact --no-banner --log-level warn . && \
	  gitleaks git --pre-commit --staged --redact --no-banner --log-level warn . && echo "gitleaks: no leaks found"; \
	else echo "WARNING: gitleaks is not installed (brew install gitleaks); secret scan skipped"; fi

hooks: ## use the project's git hooks (.githooks: gitleaks pre-commit); sets core.hooksPath in this repository only
	git config core.hooksPath .githooks
	@echo "pre-commit hook active: gitleaks scans staged changes"

audit: deps ## check gems for known vulnerabilities (downloads the advisory database)
	bin/bundler-audit check --update

check: lint test ## lint and test; must pass before a commit

run: build ## build, create the admin user from .env if missing, start http://localhost:3000
	@bin/setup-env
	@set -a; . ./.env; set +a; bin/rails db:seed && exec bin/rails server

demo: build ## add example organizations, users and tickets (development only; needs DEMO_PASSWORD)
	@test -n "$(DEMO_PASSWORD)" || { echo "DEMO_PASSWORD is not set, e.g. DEMO_PASSWORD=choose-one make demo"; exit 1; }
	bin/rails stopan:demo

screenshots: ## refresh docs/screenshots from a running dev server with demo data (needs DEMO_PASSWORD, Chrome, Node; STOPAN_URL)
	@test -n "$(DEMO_PASSWORD)" || { echo "DEMO_PASSWORD is not set (the password given to make demo)"; exit 1; }
	bin/screenshots $(or $(STOPAN_URL),http://127.0.0.1:3000)
	@if command -v pngquant >/dev/null; then for f in docs/screenshots/*.png; do pngquant --force --skip-if-larger --quality 80-95 --output "$$f" -- "$$f"; done; fi

clean: ## remove caches, logs, compiled assets and test uploads (keeps databases in storage/)
	rm -rf tmp/cache tmp/storage/* public/assets
	rm -f log/*.log

docker-build: ## build the production Docker image
	docker build -t $(IMAGE) .

docker-check: docker-build ## build the image and smoke-test it with throwaway secrets (no .env; PORT default 3190)
	bin/docker-check $(IMAGE)

docker-up: ## build and start the app with docker compose on http://localhost:3000
	@bin/setup-env
	docker compose up -d --build

docker-down: ## stop the docker compose app (data stays in the storage volume)
	docker compose down

docker-logs: ## follow the docker compose app logs
	docker compose logs -f web

deploy: ## ship HEAD to the server, build and restart there (needs DEPLOY_HOST; specs/deploy.md)
	@bin/deploy
