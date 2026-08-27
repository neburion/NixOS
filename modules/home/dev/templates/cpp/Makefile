.PHONY: build release clean re

build:
	cmake -B build && cmake --build build

release:
	cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build

clean:
	rm -rf build bin

re: clean build
