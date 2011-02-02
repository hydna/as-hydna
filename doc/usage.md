# Usage

In the following example we open a read/write stream, send a "Hello world!"
when the connection has been established and trace all received messages to
the console.

    :::actionscript
    import hydna.net.Stream;
    import hydna.net.StreamMode;
    import hydna.net.StreamDataEvent;
    import hydna.net.StreamEmitEvent;

    var stream:Stream = new Stream();

    // add an event listener that traces error message to the console, should
    // an error occur.
    stream.addEventListener("error", function(e:Event) : void {
        trace("An error occured: " + e.toString());
    });

    // add an event listener that handles incoming messages.
    stream.addEventListener("data", function(e:StreamDataEvent) : void {
        trace("Data received: " + e.data.readUTFBytes(e.data.length));
    });

    // add an event listener that sends the message "Hello world!" when
    // a connection has been established and the stream has been
    // successfully openend.
    stream.addEventListener("connect", function(e:Event) : void {
        trace("We are now connected, let's send a message.");
        stream.write("Hello world!");
    });

    // open a stream to channel 12345 on the domain demo.hydna.net in
    // read/write mode.
    stream.connect("demo.hydna.net/12345", StreamMode.READWRITE);
