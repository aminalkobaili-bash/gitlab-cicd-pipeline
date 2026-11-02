CC = gcc
CFLAGS ?= -Wall -Wextra -Werror -std=c11 -O2

.PHONY: all clean

all: DO

DO: main.c
	$(CC) $(CFLAGS) main.c -o DO

clean:
	rm -f *.o DO
