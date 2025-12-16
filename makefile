CC=gcc

CFLAGS=-fPIC -I/usr/include
LDFLAGS=-shared -ljson-c -lcurl

all:
	$(CC) $(CFLAGS) plugin.c -o plugin.so $(LDFLAGS)

clean:
	rm -f plugin.so
