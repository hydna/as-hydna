CC = mxmlc
DEST = build
SRC = -sp src

dest:
	mkdir -p $(DEST)

hello-world: dest
	$(CC) examples/hello-world/HelloWorld.as -o $(DEST)/hello-world.swf $(SRC)

performance-test: dest
	$(CC) examples/performance-test/PerformanceTest.as -o $(DEST)/performance-test.swf $(SRC)
