CC=gcc
CFLAGS=-fPIC -I/usr/include -shared

all:
	$(CC) $(CFLAGS) plugin.c -o plugin.so
