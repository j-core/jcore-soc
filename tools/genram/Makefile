all: genram-32k genram-16k

genram32.o: genram.c
	$(CC) -DRAMSIZE=32768 $< -c -o $@

genram16.o: genram.c
	$(CC) -DRAMSIZE=16384 $< -c -o $@

genram-32k: genram32.o
	$(CC) $< -o $@

genram-16k: genram16.o
	$(CC) $< -o $@

clean:
	-rm -rf genram-32k genram-16k *.o

.PHONY: clean
