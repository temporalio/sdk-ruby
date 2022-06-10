PROTO_ROOT := bridge/sdk-core/protos/api_upstream/
PROTO_FILES = $(shell find $(PROTO_ROOT) -name "*.proto")
PROTO_DIRS = $(sort $(dir $(PROTO_FILES)))
PROTO_OUT := lib/gen

proto:
	$(foreach PROTO_DIR,$(PROTO_DIRS),bundle exec protoc --proto_path=$(PROTO_ROOT) --ruby_out=$(PROTO_OUT) $(PROTO_DIR)*.proto;)

.PHONY: proto
