SHELL := /bin/sh

.PHONY: help bootstrap build up down logs verify update backup restore prune-logs shell

help:
	@echo "make bootstrap   create .env and config/config.json (if missing)"
	@echo "make build       build the image from pinned sources"
	@echo "make up          start (or recreate) the container"
	@echo "make down        stop the container"
	@echo "make logs        follow container logs"
	@echo "make verify      patch check + build + smoke test"
	@echo "make update      show upstream drift for the pinned versions"
	@echo "make backup      back up config and persistent data"
	@echo "make restore     restore the latest backup (manual path)"
	@echo "make prune-logs  delete scanner logs older than 90 days"
	@echo "make shell       open a shell in the container"

bootstrap:
	./scripts/bootstrap.sh

build:
	docker compose build

up: bootstrap
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

verify:
	./scripts/verify.sh

update:
	./scripts/update-pins.sh

backup:
	./scripts/backup.sh

restore:
	@echo "Usage: tar -xzf backup-config-<date>.tgz -C ."

prune-logs:
	./scripts/prune-logs.sh

shell:
	docker compose run --rm --entrypoint sh fm-dx-webserver
