CC = mxmlc
DIST = build
SRC = -sp src

dest:
	mkdir -p $(DIST)

hello-world: dest
	$(CC) examples/hello-world/HelloWorld.as -o $(DIST)/hello-world.swf $(SRC)

performance-test: dest
	$(CC) examples/performance-test/PerformanceTest.as -o $(DIST)/performance-test.swf $(SRC)


trace-mac:
	tail -f ~/Library/Preferences/Macromedia/Flash\ Player/Logs/flashlog.txt


.PHONY: hello-world performance-test trace-mac