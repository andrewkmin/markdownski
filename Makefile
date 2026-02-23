.PHONY: build run clean universal dmg

build:
	swift build -c release
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@echo "Built markdownski.app"

universal:
	swift build -c release --arch arm64 --arch x86_64
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/apple/Products/Release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/apple/Products/Release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@echo "Built markdownski.app (universal)"

dmg: universal
	rm -f markdownski.dmg
	mkdir -p dmg-staging
	cp -R markdownski.app dmg-staging/
	ln -s /Applications dmg-staging/Applications
	hdiutil create -volname "markdownski" -srcfolder dmg-staging -ov -format UDZO markdownski.dmg
	rm -rf dmg-staging
	@echo "Built markdownski.dmg"

run: build
	open markdownski.app

clean:
	swift package clean
	rm -rf markdownski.app markdownski.dmg dmg-staging
