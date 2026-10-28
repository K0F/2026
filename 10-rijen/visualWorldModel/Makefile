CC ?= gcc
CFLAGS ?= -O3 -march=native -Wall -Wextra -D_POSIX_C_SOURCE=200809L
LDFLAGS ?= -lraylib -lm -lpthread

TARGET = gesture_conductor
SRC = gesture_conductor.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)

run-headless: $(TARGET)
	./$(TARGET) --headless

.PHONY: all clean run run-headless
