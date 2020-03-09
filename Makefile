GOFLAGS := -ldflags="-H windowsgui -s -w" -v -tags walk_use_cgo -trimpath
export CGO_ENABLED := 1
export CGO_CFLAGS := -O3 -Wall -Wno-unused-function -Wno-switch -std=gnu11 -DWINVER=0x0601
export CGO_LDFLAGS := -Wl,--dynamicbase -Wl,--nxcompat -Wl,--export-all-symbols
export GOOS := windows

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))
SOURCE_FILES := $(call rwildcard,,*.go *.c *.h) go.mod go.sum
RESOURCE_FILES := resources.rc version/version.h manifest.xml $(patsubst %.svg,%.ico,$(wildcard ui/icon/*.svg))

DEPLOYMENT_HOST ?= winvm
DEPLOYMENT_PATH ?= Desktop

all: amd64/wireguard.exe x86/wireguard.exe

%.ico: %.svg
	convert -background none $< -define icon:auto-resize="256,192,128,96,64,48,32,24,16" $@

resources_amd64.syso: $(RESOURCE_FILES)
	x86_64-w64-mingw32-windres -i $< -o $@ -O coff

resources_386.syso: $(RESOURCE_FILES)
	i686-w64-mingw32-windres -i $< -o $@ -O coff

amd64/wireguard.exe: export CC := x86_64-w64-mingw32-gcc
amd64/wireguard.exe: export GOARCH := amd64
amd64/wireguard.exe: CGO_LDFLAGS += -Wl,--high-entropy-va
amd64/wireguard.exe: resources_amd64.syso $(SOURCE_FILES)
	go build $(GOFLAGS) -o $@

x86/wireguard.exe: export CC := i686-w64-mingw32-gcc
x86/wireguard.exe: export GOARCH := 386
x86/wireguard.exe: resources_386.syso $(SOURCE_FILES)
	go build $(GOFLAGS) -o $@

remaster: export CC := x86_64-w64-mingw32-gcc
remaster: export GOARCH := amd64
remaster: export GOPROXY := direct
remaster:
	rm -f go.sum go.mod
	cp go.mod.master go.mod
	go get -d

fmt: export CC := x86_64-w64-mingw32-gcc
fmt: export GOARCH := amd64
fmt:
	go fmt ./...

generate: export CC := i686-w64-mingw32-gcc
generate: export GOARCH := 386
generate:
	go generate

deploy: amd64/wireguard.exe
	-ssh $(DEPLOYMENT_HOST) -- 'taskkill /im wireguard.exe /f'
	scp $< $(DEPLOYMENT_HOST):$(DEPLOYMENT_PATH)

clean:
	rm -rf *.syso ui/icon/*.ico x86/ amd64/

.PHONY: deploy clean fmt remaster all
