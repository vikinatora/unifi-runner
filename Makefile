.PHONY: all build run clean start-l1-devnet

all: jwt-token build run

build:
	mkdir -p ./data/taiko-client
	docker compose build

run:
	docker compose up -d

clean:
	docker compose down
	docker compose rm -f
	rm -rf data/

start-l1-devnet:
	./run_kurtosis.sh

jwt-token:
	openssl rand -hex 32 > jwt.txt