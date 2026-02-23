.PHONY: build run clean

build:
	swift build -c release
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@echo "Built markdownski.app"

run: build
	open markdownski.app

clean:
	swift package clean
	rm -rf markdownski.app
