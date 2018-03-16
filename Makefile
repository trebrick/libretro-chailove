TARGET_NAME := chailove

include Makefile.libretro

ifeq ($(STATIC_LINKING),1)
	FLAGS += -DSTATIC_LINKING
endif

FLAGS += -D__LIBRETRO__ $(COREDEFINES) $(ENDIANNESS_DEFINES) $(PLATFORM_DEFINES) $(WARNINGS) $(fpic)

CXXFLAGS += $(FLAGS) -std=c++14
CFLAGS += $(FLAGS) -std=gnu99

# Ignore first attempt builds, and re-try for a cleaner dependency chain.
all: $(TARGET)
	$(MAKE) $(TARGET)

$(TARGET): $(OBJECTS) | vendor/libretro-common/include/libretro.h
	-$(CXX) -o $@ $^ $(LDFLAGS)

%.o: %.cpp | vendor/libretro-common/include/libretro.h
	-$(CXX) -c -o $@ $< $(CXXFLAGS)

%.o: %.c | vendor/libretro-common/include/libretro.h
	-$(CC) -c -o $@ $< $(CFLAGS)

clean:
	rm -f $(TARGET) $(OBJECTS)
	git clean -xdf
	rm -rf vendor
	git submodule update --init --recursive
	git submodule foreach --recursive git clean -xfd
	git submodule foreach --recursive git reset --hard HEAD

vendor/libretro-common/include/libretro.h:
	@git submodule update --init --recursive

test: unittest cpplint
	@echo "Run the testing suite by using:\n\n    retroarch -L $(TARGET) test/main.chai\n\n"

vendor/noarch/noarch: vendor/libretro-common/include/libretro.h
	@$(MAKE) -C vendor/noarch

unittest: vendor/noarch/noarch all
	vendor/noarch/noarch $(CORE_DIR)/$(TARGET) test/unittests/main.chai

examples: all
	@retroarch -L $(TARGET) examples/benchmark/main.chai

test-script: all
	@retroarch -L $(TARGET) test/main.chai

docs: dependencies
	doxygen docs/Doxyfile

docs-start: docs
	php -S localhost:9999 -t docs/html

docs-deploy: docs
	npm install push-dir && node_modules/.bin/push-dir --dir=docs/html --branch=docs

cpplint: vendor
	@vendor/styleguide/cpplint/cpplint.py \
		--linelength=120 \
		--quiet \
		--counting=detailed \
		--filter=-build/include,-legal/copyright,-runtime/int,-runtime-readability/braces,\
	-runtime/threadsafe_fn,-build/namespaces,-runtime/explicit,-whitespace/tab,\
	-readability/casting,-whitespace/line_length,-runtime/references \
		src/*.h src/*.cpp src/love/*.h src/love/*.cpp src/love/Types/*/*.h src/love/Types/*/*.cpp

tests: vendor
	$(MAKE) HAVE_CHAISCRIPT=0 HAVE_TESTS=1

test-native: tests
	retroarch -L $(TARGET) test/native/main.chai

PREFIX := /usr
INSTALLDIR := $(PREFIX)/lib/libretro
install: all
	mkdir -p $(DESTDIR)$(INSTALLDIR)
	cp $(TARGET) $(DESTDIR)$(INSTALLDIR)
