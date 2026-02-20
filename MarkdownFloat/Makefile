.PHONY: build run clean

build:
	swift build -c release
	mkdir -p MarkdownFloat.app/Contents/MacOS
	mkdir -p MarkdownFloat.app/Contents/Resources
	cp .build/release/MarkdownFloat MarkdownFloat.app/Contents/MacOS/
	cp Info.plist MarkdownFloat.app/Contents/
	cp -R .build/release/MarkdownFloat_MarkdownFloat.bundle MarkdownFloat.app/Contents/Resources/
	@echo "Built MarkdownFloat.app"

run: build
	open MarkdownFloat.app

clean:
	swift package clean
	rm -rf MarkdownFloat.app
