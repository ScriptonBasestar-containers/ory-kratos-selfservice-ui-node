rand := $(shell openssl rand -hex 6)
ORG_NAME := scriptonbasestar
REPO_PREFIX := ory-

.PHONY: docker-dev-build
docker-dev-build:
	docker build -f ./Dockerfile-dev -t kratos-ui-node-dev . --platform linux/amd64 --platform linux/arm64

docker-dev-deploy:
	docker tag kratos-ui-node-dev ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:dev
	docker push ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:dev

.PHONY: docker-build
docker-build:
	docker build -t kratos-ui-node . --platform linux/amd64 --platform linux/arm64

.PHONY: docker-deploy
docker-deploy:
	docker tag kratos-ui-node ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:prd
	docker tag kratos-ui-node ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:latest
	docker push ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:prd
	docker push ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:latest

.PHONY: build-sdk
build-sdk:
	(cd $$KRATOS_DIR; make sdk)
	cp $$KRATOS_DIR/spec/api.json ./contrib/sdk/api.json
	npx @openapitools/openapi-generator-cli generate -i "./contrib/sdk/api.json" \
		-g typescript-axios \
		-o "./contrib/sdk/generated" \
		--git-user-id ory \
		--git-repo-id sdk \
		--git-host github.com \
		-c ./contrib/sdk/typescript.yml
	(cd ./contrib/sdk/generated; npm i; npm run build)
	rm -rf node_modules/@ory/client/*
	cp -r ./contrib/sdk/generated/* node_modules/@ory/client

.PHONY: publish-sdk
publish-sdk: build-sdk
	(cd ./contrib/sdk/generated/; \
		npm --no-git-tag-version version v0.0.0-next.$(rand) && \
		npm publish)
	rm -rf node_modules/@ory/client/*
	sleep 15
	npm i @ory/client@0.0.0-next.$(rand)

.PHONY: build-sdk-docker
build-sdk-docker: build-sdk
	docker build -t ${ORG_NAME}/${REPO_PREFIX}kratos-selfservice-ui-node:latest . --build-arg LINK=true

.PHONY: clean-sdk
clean-sdk:
	rm -rf node_modules/@ory/client/
	npm i

format: .bin/ory node_modules
	.bin/ory dev headers copyright --type=open-source --exclude=.prettierrc.js --exclude=types
	npm exec -- prettier --write .

licenses: .bin/licenses node_modules  # checks open-source licenses
	.bin/licenses

.bin/licenses: Makefile
	curl https://raw.githubusercontent.com/ory/ci/master/licenses/install | sh

.bin/ory: Makefile
	curl https://raw.githubusercontent.com/ory/meta/master/install.sh | bash -s -- -b .bin ory v0.2.1
	touch .bin/ory

node_modules: package-lock.json
	npm ci --legacy-peer-deps
	touch node_modules
