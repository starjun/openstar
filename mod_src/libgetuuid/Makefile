
.PHONY: all clean depend

CFLAGS := -L. -Wl,-rpath,. -Wall -fvisibility=hidden -rdynamic -fstack-protector-all -fno-common -O2 -fPIC
INCLUDE := -I./
LDFLAGS := -shared -llua
LUA_SO=/usr/local/lib/libluajit-5.1.so
CC := g++

SRCS := $(wildcard *.cpp)
OBJS := $(patsubst %.cpp,%.o,$(SRCS))


TARGET := libgetuuid.so

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)

%.o:%.cpp
	$(CC) -c $(INCLUDE) $(CFLAGS) $< -o $@

explain:
	@echo "The information represents in the program:"
	@echo "Final executable name: $(TARGET)"
	@echo "Source files: $(SRCS)"
	@echo "Object files: $(OBJS)"

clean:
	rm -f $(TARGET) $(OBJS)

