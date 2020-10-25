.PHONY: clean test build js c rust doc ios_pre_build run_c

SRC=$(PROJ)/src
CC=clang
NIM_TOOLCHAIN=~/.choosenim/toolchains/nim-1.2.2/lib

build:
	nimble build main --sourceMap:on --stackTrace:on

js:
	nimble js ./src/app.nim --outDir=./dist/js

c:
	nimble c ./src/app.nim --outDir=./dist/native

# Note: This target currently crashes
c_hot_reload:
	nim c --outdir:./dist/native $(NIM_TOOLCHAIN)/nimhcr.nim
	nim c --outdir:./dist/native $(NIM_TOOLCHAIN)/nimrtl.nim
	nimble c ./src/app.nim --outDir=./dist/native --hotcodereloading:on
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(PWD)/dist/native ./dist/native/app
.PHONY: c_hot_reload

debug_c:
	nimble c ./src/app.nim --outDir=./dist/native_debug --debugger:native

run_c: c
	./dist/native/app

profile_nimprof:
	nimble c ./src/app.nim --outDir=./dist/native --profiler:on --stackTrace:on
	./dist/native/app

profile_valgrind:
	nimble c ./src/app.nim --outDir=./dist/native --debugger:native --profiler:on --stackTrace:on
	valgrind --tool=callgrind ./dist/native/app
	#callgrind_annotate callgrind.out.<pid>

RUST_NIM_LIB_PATH=$(PWD)/rust_target/target/nim_lib
rust:
	nimble c --noMain --noLinking --nimcache:./rust_target/nimcache --header main.h ./src/main.nim
	ar rcs ./rust_target/libnim_main.a ./rust_target/nimcache/**.nim.c.o
	cd $(PWD)/rust_target && cargo rustc -- -L $(PWD)/rust_target/

ios_pre_build:
	nimble c -c ./src/main.nim --os:ios --nimcache:./ios_target/endeavour/nimcache --noMain:on --noLinking:on --header

rust_run: rust
	cd $(PWD)/rust_target && cargo run

check:
	nim check ./src/js_main.nim

doc:
	mkdir -p ./docs
	nim doc --project --index\:on --outdir:./docs/ --nimcache:./docs/ ./src/main.nim   #--git.url\:<url> --git.commit\:<tag> 
	nim buildIndex -o:./docs/index.html docs

test:
	nim c --path="../src/" -r ./tests/t_state_machine.nim

build_all: js c
