CC = `which mxmlc`
ASDOC = `which asdoc`
DIST = build
SRC = -sp src

dest:
	mkdir -p $(DIST)

hello-world: dest
	$(CC) -debug=true examples/hello-world/HelloWorld.as -o $(DIST)/hello-world.swf $(SRC)

performance-test: dest
	$(CC) examples/performance-test/PerformanceTest.as -o $(DIST)/performance-test.swf $(SRC)

test: dest
	$(CC) test/Runner.as -o $(DIST)/test.swf $(SRC) && open $(DIST)/test.swf

doc:
	$(ASDOC) -doc-sources src\
					 -output doc\
					 -main-title "Hydna bindings for Actionscript 3"

.PHONY: hello-world performance-test doc