# Standard targets for every project under AI/ (see ../AGENTS.md).

.DEFAULT_GOAL := help

IMAGE ?= stopan:latest

.PHONY: help ruby deps build test lint audit check secrets hooks run demo screenshots clean docker-build docker-check docker-up docker-down docker-logs docker-dev docker-dev-restart docker-dev-logs docker-dev-down deploy release

help: ## list the targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-18s %s\n", $$1, $$2}'

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

audit: deps ## check gems for known vulnerabilities (updates the advisory database; offline uses the local copy)
	@bin/bundler-audit update --quiet || echo "WARNING: could not update the advisory database; checking against the local copy"
	bin/bundler-audit check

check: lint audit test ## lint, gem audit and test; must pass before a commit

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

docker-dev: ## run development mode in docker on http://localhost:3000 from the source tree with demo data; code changes apply live
	@bin/setup-env
	docker compose -f compose.dev.yaml up -d --build
	@echo "http://localhost:$${DEV_PORT:-3000} (first start installs gems; make docker-dev-logs to watch)"

docker-dev-restart: ## restart the development container after Gemfile or config/ changes
	docker compose -f compose.dev.yaml restart dev

docker-dev-logs: ## follow the development container logs
	docker compose -f compose.dev.yaml logs -f dev

docker-dev-down: ## stop the development container (gems, database and tmp stay in volumes)
	docker compose -f compose.dev.yaml down

release: ## tag main as vVERSION and publish the GitHub release with notes from bin/release-notes (VERSION=x.y.z; specs/release.md)
	@test -n "$(VERSION)" || { echo "VERSION is missing: make release VERSION=0.1.0"; exit 1; }
	@echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "VERSION must be three numbers without a leading v, for example 0.1.0 (got $(VERSION))"; exit 1; }
	@command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { echo "gh is missing or not signed in (gh auth login)"; exit 1; }
	@test "$$(git rev-parse --abbrev-ref HEAD)" = main || { echo "releases are made from main"; exit 1; }
	@git diff --quiet && git diff --cached --quiet || { echo "tracked files have uncommitted changes; commit or stash them first"; exit 1; }
	@git fetch -q origin main --tags
	@test "$$(git rev-parse HEAD)" = "$$(git rev-parse origin/main)" || { echo "HEAD differs from origin/main; push or pull first"; exit 1; }
	@! git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "tag v$(VERSION) already exists"; exit 1; }
	$(MAKE) check
	@mkdir -p tmp
	bin/release-notes > tmp/release-notes-v$(VERSION).md
	git tag -a v$(VERSION) -m "Stopan v$(VERSION)"
	git push origin v$(VERSION)
	gh release create v$(VERSION) --verify-tag --latest --title "Stopan v$(VERSION)" --notes-file tmp/release-notes-v$(VERSION).md

deploy: ## ship HEAD to the server, build and restart there (needs DEPLOY_HOST; specs/deploy.md)
	@bin/deploy
