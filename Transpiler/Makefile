
CC = gcc
CFLAGS = -Wall -Wextra -g
LDFLAGS = -lfl

SRCS = parser.tab.c lex.yy.c ast.c symtab.c translation.c utils.c
OBJS = $(SRCS:.c=.o)

TARGET = cpp2py

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

parser.tab.c parser.tab.h: parser.y
	bison -d parser.y

lex.yy.c: scanner.l
	flex scanner.l

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f $(TARGET) $(OBJS) parser.tab.c parser.tab.h lex.yy.c 
