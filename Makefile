all: install

install:
	@echo "Installation (have a look at build.log for details)";
	@echo "" > build.log
	@echo "  * Building...(can take some minutes)";
	@xcodebuild -project GPGPreferences.xcodeproj -target GPGPreferences -configuration Release build >> build.log 2>&1
	@echo "  * Installing...";
	@mkdir -p ~/Library/PreferencePanes >> build.log 2>&1
	@rm -rf ~/Library/PreferencePanes/GnuPG.prefPane >> build.log 2>&1
	@cp -r build/Release/GnuPG.prefPane ~/Library/PreferencePanes >> build.log 2>&1

clean-gpgme:
	rm -rf Dependencies/MacGPGME/build

clean-GPGPreferences:
	xcodebuild -project GPGPreferences.xcodeproj -target GPGPreferences -configuration Release clean > /dev/null
	xcodebuild -project GPGPreferences.xcodeproj -target GPGPreferences -configuration Debug clean > /dev/null

clean: clean-gpgme clean-GPGPreferences

check-all-warnings: clean-GPGPreferences
	make | grep "warning: "

check-warnings: clean-GPGPreferences
	make | grep "warning: "|grep -v "#warning"

check: clean-GPGPreferences
	@if [ "`which scan-build`" == "" ]; then echo 'usage: PATH=$$PATH:path_to_scan_build make check'; echo "see: http://clang-analyzer.llvm.org/"; exit; fi
	@echo "";
	@echo "Have a closer look at these warnings:";
	@echo "=====================================";
	@echo "";
	@scan-build -analyzer-check-objc-missing-dealloc \
	            -analyzer-check-dead-stores \
	            -analyzer-check-idempotent-operations \
	            -analyzer-check-llvm-conventions \
	            -analyzer-check-objc-mem \
	            -analyzer-check-objc-methodsigs \
	            -analyzer-check-objc-missing-dealloc \
	            -analyzer-check-objc-unused-ivars \
	            -analyzer-check-security-syntactic \
	            --use-cc clang -o build/report xcodebuild \
	            -project GPGPreferences.xcodeproj -target GPGPreferences \
	            -configuration Release build 2>error.log|grep "is deprecated"
	@echo "";
	@echo "Now have a look at build/report/ or at error.log";

style:
	@if [ "`which uncrustify`" == "" ]; then echo 'usage: PATH=$$PATH:path_to_uncrustify make style'; echo "see: https://github.com/bengardner/uncrustify"; exit; fi
	uncrustify -c Utilities/uncrustify.cfg --no-backup Source/*.h
	uncrustify -c Utilities/uncrustify.cfg --no-backup Source/*.m
	uncrustify -c Utilities/uncrustify.cfg --no-backup Source/PrivateHeaders/*
	uncrustify -c Utilities/uncrustify.cfg --no-backup Source/GPG.subproj/*

