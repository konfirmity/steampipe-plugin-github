STEAMPIPE_INSTALL_DIR ?= ~/.steampipe
BUILD_TAGS = netgo
install:
	go build -o $(STEAMPIPE_INSTALL_DIR)/plugins/hub.steampipe.io/plugins/turbot/github@latest/steampipe-plugin-github.plugin -tags "${BUILD_TAGS}" *.go

# Build the plugin as a standalone Postgres FDW extension
# (steampipe_postgres_github.so + .control + .sql in build/postgres/) using
# turbot/steampipe-postgres-fdw. Requires pg_config on PATH. The FDW is cloned unpinned: its main
# branch is on steampipe-plugin-sdk v6, as is this plugin.
postgres:
	rm -rf build/steampipe-postgres-fdw && mkdir -p build
	git clone --quiet --depth 1 https://github.com/turbot/steampipe-postgres-fdw.git build/steampipe-postgres-fdw
	cd build/steampipe-postgres-fdw && \
		$(MAKE) prebuild.go && \
		rm -rf work && mkdir -p work && rsync -a --exclude='.git' . work/
	cd build/steampipe-postgres-fdw/work && \
		go run generate/generator.go templates . github "" github.com/turbot/steampipe-plugin-github && \
		echo 'replace github.com/turbot/steampipe-plugin-github => $(CURDIR)' >> go.mod && \
		go mod tidy && \
		$(MAKE) -C ./fdw clean plugin=github && \
		$(MAKE) -C ./fdw go plugin=github && \
		$(MAKE) -C ./fdw plugin=github && \
		$(MAKE) -C ./fdw standalone plugin=github
	rm -rf build/postgres && mkdir -p build/postgres
	cp -a build/steampipe-postgres-fdw/work/build-$(shell uname)/* build/postgres/
	@echo "Built build/postgres/ (steampipe_postgres_github extension)"

clean:
	rm -rf build
