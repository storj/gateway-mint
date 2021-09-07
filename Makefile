.PHONY: build-image
build-image:
	docker build --pull -t storjlabs/gateway-mint:latest-amd64 .
	docker build --pull -t storjlabs/gateway-mint:latest-arm32v6 \
		--build-arg=GOARCH=arm --build-arg=DOCKER_ARCH=arm32v6 .
	docker build --pull -t storjlabs/gateway-mint:latest-aarch64 \
		--build-arg=GOARCH=arm64 --build-arg=DOCKER_ARCH=aarch64 .

.PHONY: push-image
push-image:
	docker push storjlabs/gateway-mint:latest-amd64
	docker push storjlabs/gateway-mint:latest-arm32v6
	docker push storjlabs/gateway-mint:latest-aarch64
	docker manifest create storjlabs/gateway-mint:latest \
		storjlabs/gateway-mint:latest-amd64 \
		storjlabs/gateway-mint:latest-arm32v6 \
		storjlabs/gateway-mint:latest-aarch64
	docker manifest annotate storjlabs/gateway-mint:latest \
		storjlabs/gateway-mint:latest-amd64 --os linux --arch amd64
	docker manifest annotate storjlabs/gateway-mint:latest \
		storjlabs/gateway-mint:latest-arm32v6 --os linux --arch arm --variant v6
	docker manifest annotate storjlabs/gateway-mint:latest \
		storjlabs/gateway-mint:latest-aarch64 --os linux --arch arm64
	docker manifest push --purge storjlabs/gateway-mint:latest

.PHONY: clean-image
clean-image:
	# ignore errors during cleanup by preceding commands with dash
	-docker rmi storjlabs/gateway-mint:latest-amd64
	-docker rmi storjlabs/gateway-mint:latest-arm32v6
	-docker rmi storjlabs/gateway-mint:latest-aarch64
