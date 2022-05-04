.PHONY: build-image
build-image:
	docker build --pull -t storjlabs/gateway-mint .

.PHONY: push-image
push-image:
	docker push storjlabs/gateway-mint:latest

.PHONY: clean-image
clean-image:
	# ignore errors during cleanup by preceding commands with dash
	-docker rmi storjlabs/gateway-mint:latest

.PHONY: ci-image-build
ci-image-build:
	docker build --pull -t storjlabs/gateway-mint:latest .

.PHONY: ci-image-run
ci-image-run:
	# Every Makefile rule is run in its shell, so we need to couple these two so
	# exported credentials are visible to the `docker run ...` command.
	export $$(docker run --network gateway-mint-network-$$BUILD_NUMBER --rm storjlabs/authservice:dev register --address drpc://authservice:20002 --format-env $$(docker exec gateway-mint-sim-$$BUILD_NUMBER storj-sim network env GATEWAY_0_ACCESS)); \
	docker run \
	--network gateway-mint-network-$$BUILD_NUMBER \
	-e "SERVER_ENDPOINT=gateway:20010" -e "ACCESS_KEY=$$AWS_ACCESS_KEY_ID" -e "SECRET_KEY=$$AWS_SECRET_ACCESS_KEY" -e "ENABLE_HTTPS=0" \
	--name gateway-mint-mint-$$BUILD_NUMBER \
	--rm storjlabs/gateway-mint:latest

.PHONY: ci-image-clean
ci-image-clean:
	-docker rmi storjlabs/gateway-mint:latest

.PHONY: ci-network-create
ci-network-create:
	docker network create gateway-mint-network-$$BUILD_NUMBER

.PHONY: ci-network-remove
ci-network-remove:
	-docker network remove gateway-mint-network-$$BUILD_NUMBER

.PHONY: ci-dependencies-start
ci-dependencies-start:
	docker run \
	--network gateway-mint-network-$$BUILD_NUMBER --network-alias postgres \
	-e POSTGRES_DB=sim -e POSTGRES_HOST_AUTH_METHOD=trust \
	--name gateway-mint-postgres-$$BUILD_NUMBER \
	--rm -d postgres:latest

	docker run \
	--network gateway-mint-network-$$BUILD_NUMBER --network-alias redis \
	--name gateway-mint-redis-$$BUILD_NUMBER \
	--rm -d redis:latest

	docker run \
	--network gateway-mint-network-$$BUILD_NUMBER --network-alias sim \
	-e STORJ_SIM_POSTGRES='postgres://postgres@postgres/sim?sslmode=disable' -e STORJ_SIM_REDIS=redis:6379 \
	-v $$PWD/jenkins:/jenkins:ro \
	--name gateway-mint-sim-$$BUILD_NUMBER \
	--rm -d golang:latest /jenkins/start_storj-sim.sh

	# We need to block until storj-sim finishes its build and launches;
	# otherwise, we would pass an invalid satellite ID/address to authservice.
	until docker exec gateway-mint-sim-$$BUILD_NUMBER storj-sim network env SATELLITE_0_ID > /dev/null; do \
		echo "*** storj-sim is not yet available; waiting for 3s..." && sleep 3; \
	done

	docker run \
	--network gateway-mint-network-$$BUILD_NUMBER --network-alias authservice \
	--name gateway-mint-authservice-$$BUILD_NUMBER \
	--rm -d storjlabs/authservice:dev run \
		--allowed-satellites $$(docker exec gateway-mint-sim-$$BUILD_NUMBER storj-sim network env SATELLITE_0_ID)@ \
		--auth-token super-secret \
		--endpoint http://gateway:20010 \
		--kv-backend memory://

	docker run \
	--network gateway-mint-network-$$BUILD_NUMBER --network-alias gateway \
	--name gateway-mint-gateway-$$BUILD_NUMBER \
	--rm -d storjlabs/gateway-mt:dev run \
		--auth.base-url http://authservice:20000 \
		--auth.token super-secret \
		--domain-name gateway \
		--insecure-log-all \
		--s3compatibility.fully-compatible-listing

.PHONY: ci-dependencies-stop
ci-dependencies-stop:
	-docker stop gateway-mint-gateway-$$BUILD_NUMBER
	-docker stop gateway-mint-authservice-$$BUILD_NUMBER
	-docker stop gateway-mint-sim-$$BUILD_NUMBER
	-docker stop gateway-mint-redis-$$BUILD_NUMBER
	-docker stop gateway-mint-postgres-$$BUILD_NUMBER

.PHONY: ci-dependencies-clean
ci-dependencies-clean:
	-docker rmi storjlabs/gateway-mt:dev
	-docker rmi storjlabs/authservice:dev
	-docker rmi golang:latest
	-docker rmi redis:latest
	-docker rmi postgres:latest

.PHONY: ci-run
ci-run: ci-image-build ci-network-create ci-dependencies-start ci-image-run

.PHONY: ci-purge
ci-purge: ci-dependencies-stop ci-dependencies-clean ci-network-remove ci-image-clean
