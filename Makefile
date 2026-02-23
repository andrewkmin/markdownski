.PHONY: build run clean universal dmg

build:
	swift build -c release
	rm -rf markdownski.app
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@test -f markdownski.app/Contents/MacOS/markdownski || (echo "ERROR: binary missing from .app bundle" && exit 1)
	@test -f markdownski.app/Contents/Info.plist || (echo "ERROR: Info.plist missing from .app bundle" && exit 1)
	@test -d markdownski.app/Contents/Resources/markdownski_markdownski.bundle || (echo "ERROR: resource bundle missing from .app bundle" && exit 1)
	@echo "Built markdownski.app"

universal:
	swift build -c release --arch arm64 --arch x86_64
	rm -rf markdownski.app
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/apple/Products/Release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/apple/Products/Release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@test -f markdownski.app/Contents/MacOS/markdownski || (echo "ERROR: binary missing from .app bundle" && exit 1)
	@test -f markdownski.app/Contents/Info.plist || (echo "ERROR: Info.plist missing from .app bundle" && exit 1)
	@test -d markdownski.app/Contents/Resources/markdownski_markdownski.bundle || (echo "ERROR: resource bundle missing from .app bundle" && exit 1)
	@lipo -info markdownski.app/Contents/MacOS/markdownski | grep -q "arm64 x86_64\|x86_64 arm64" || (echo "ERROR: binary is not universal" && exit 1)
	@echo "Built markdownski.app (universal)"

dmg: universal
	rm -f markdownski.dmg
	rm -rf dmg-staging
	mkdir dmg-staging
	cp -R markdownski.app dmg-staging/
	ln -s /Applications dmg-staging/Applications
	hdiutil create -volname "markdownski" -srcfolder dmg-staging -ov -format UDZO markdownski.dmg
	rm -rf dmg-staging
	@test -f markdownski.dmg || (echo "ERROR: DMG creation failed" && exit 1)
	@echo "Built markdownski.dmg"

run: build
	open markdownski.app

clean:
	swift package clean
	rm -rf markdownski.app markdownski.dmg dmg-staging
