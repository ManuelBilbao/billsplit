.PHONY: help setup server test compile migrate reset seed format lint clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Install deps, create DB, run migrations
	mix setup

server: ## Start Phoenix dev server with IEx
	iex -S mix phx.server

iex: ## Start Phoenix dev server with IEx
	iex -S mix phx.server

test: ## Run all tests
	mix test

test-watch: ## Run tests on file changes
	mix test --stale --listen-on-stdin

compile: ## Compile the project
	mix compile

migrate: ## Run pending migrations
	mix ecto.migrate

rollback: ## Rollback last migration
	mix ecto.rollback

reset: ## Drop, create, and migrate database
	mix ecto.reset

seed: ## Run seed script
	mix run priv/repo/seeds.exs

format: ## Format all Elixir files
	mix format

lint: ## Compile with warnings as errors
	mix compile --warnings-as-errors

clean: ## Clean build artifacts
	mix clean
	rm -rf _build

deps: ## Fetch and compile dependencies
	mix deps.get && mix deps.compile

routes: ## Show all routes
	mix phx.routes
