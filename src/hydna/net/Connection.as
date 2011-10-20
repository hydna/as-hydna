// Connection.as

/**
 *        Copyright 2010 Hydna AB. All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY HYDNA AB ``AS IS'' AND ANY EXPRESS
 *  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL HYDNA AB OR CONTRIBUTORS BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 *  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 *  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 *  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 *  SUCH DAMAGE.
 *
 *  The views and conclusions contained in the software and documentation are
 *  those of the authors and should not be interpreted as representing
 *  official policies, either expressed or implied, of Hydna AB.
 */


package hydna.net {

  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.errors.IOError;
  import flash.errors.EOFError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;

  import hydna.net.OpenRequest;
  import hydna.net.Frame;
  import hydna.net.Channel;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelErrorEvent;
  import hydna.net.ChannelSignalEvent;
  import hydna.net.ChannelCloseEvent;
  import hydna.net.URLParser;

  // Internal wrapper around flash.net.Socket
  internal class Connection extends Socket {

    private static const MAX_REDIRECT_ATTEMPTS:Number = 5;
    private static const DEFAULT_PORT:Number = 80;

    private static const BROADCAST_ALL:Number = 0;

    private static const HANDSHAKE_SIZE:Number = 8;
    private static const HANDSHAKE_RESP_SIZE:Number = 5;

    private static const SUCCESS:Number = 0;
    private static const CUSTOM_ERR_CODE:Number = 0xf;

    private static var availableSockets:Dictionary;

    public static var followRedirects:Boolean = true;

    private var _attempt:Number;
    private var _handshakeBuffer:String;

    private var _connecting:Boolean = false;
    private var _handshaked:Boolean = false;

    private var _id:String;
    private var _receiveBuffer:ByteArray;
    private var _urlobj:Object;
    private var _url:String;

    private var _pendingOpenRequests:Dictionary;
    private var _openChannels:Dictionary;
    private var _openWaitQueue:Dictionary;

    private var _channelRefCount:Number = 0;

    {
      availableSockets = new Dictionary();
    }

    // Return an available connection or create a new one.
    internal static function getConnection(url:String) : Connection {
      var urlobj:Object = URLParser.parse(url);
      var connection:Connection;
      var connid:String;

      connid = [
        urlobj.host,
        ":", (urlobj.port || DEFAULT_PORT),
        "/", urlobj.path || ""
      ].join("");

      if (availableSockets[connid]) {
        connection = availableSockets[connid];
      } else {
        connection = new Connection(connid);
        connection.handshake(urlobj);
        availableSockets[connid] = connection;
      }

      return connection;
    }

    /**
     *  Initializes a new Channel instance
     */
    public function Connection(id:String) {
      super();

      _id = id;

      _receiveBuffer = new ByteArray();

      _pendingOpenRequests = new Dictionary();
      _openChannels = new Dictionary();
      _openWaitQueue = new Dictionary();

      addEventListener(Event.CLOSE, closeHandler);
      addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
      addEventListener(SecurityErrorEvent.SECURITY_ERROR,
                       securityErrorHandler);
    }


    internal function get id()  : String {
      return _id;
    }


    internal function get url() : String {
      return _url;
    }


    internal function get handshaked() : Boolean {
      return _handshaked;
    }


    internal function handshake(urlobj:Object) : void {

      if (_connecting == true) {
        throw new Error("Already connecting");
      }

      addEventListener(Event.CONNECT, connectHandler);
      addEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);

      _urlobj = urlobj;

      _attempt = _attempt ? _attempt + 1 : 1;
      _handshakeBuffer = "";

      _connecting = true;

      connect(urlobj.host, urlobj.port || DEFAULT_PORT);
    }


    private function connectHandler(event:Event) : void {
      var packet:Array = new Array();

      removeEventListener(Event.CONNECT, connectHandler);

      // TODO: Initialize a handshake timeout handler

      packet[0] = "GET /" + (_urlobj.path || "") + " HTTP/1.1";
      packet[1] = "Connection: Upgrade";
      packet[2] = "Upgrade: winksock/1";
      packet[3] = "Host: " + _urlobj.host;
      packet[4] = "X-Accept-Redirects: " + (followRedirects ? "yes" : "no");
      packet[5] = "\r\n";

      this.writeMultiByte(packet.join("\r\n"), "us-ascii");

      try {
        flush();
      } catch (error:Error) {
        destroy(ChannelErrorEvent.fromError(error));
        return;
      }
    }


    private function handshakeHandler(event:ProgressEvent) : void {
      var request:OpenRequest;
      var buffer:String;
      var splitted:Array;
      var head:Array;
      var body:String;
      var headers:Array;
      var m:Object;
      var status:Number;

      buffer = readUTFBytes(bytesAvailable);

      _handshakeBuffer += buffer;

      splitted = _handshakeBuffer.split("\r\n\r\n");

      if (splitted.length == 1) {
        // Need more bytes here, header end was not received yet.
        return;
      }

      head = splitted[0].split("\r\n");
      body = splitted[1];

      if (body && body.indexOf("\r") != -1) {
        body = body.substr(0, body.indexOf("\r"));
      }

      this.removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);

      m = /HTTP\/1\.1\s(\d+)/.exec(head[0]);

      if (!m) {
        destroy(new ChannelErrorEvent("Bad handshake (HTTP decoding)"));
        return;
      }

      if (isNaN(status = int(m[1]))) {
        destroy(new ChannelErrorEvent("Bad handshake (HTTP status missing)"));
        return;
      }

      _connecting = false;

      switch (status) {

        case 101:
          // Accepted and upgraded. Write all pending
          // open requests to Socket.

          // TODO: Add winksock/1 validation here!

          _handshaked = true;

          _receiveBuffer = new ByteArray();
          this.addEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);

          for (var key:Object in _pendingOpenRequests) {
            request = OpenRequest(_pendingOpenRequests[key]);
            writeBytes(request.frame);
            request.sent = true;
          }

          try {
            flush();
          } catch (error:Error) {
            destroy(ChannelErrorEvent.fromError(error));
          }

          return;

        case 300:
        case 301:
        case 302:
        case 303:
        case 304:

          if (followRedirects == false) {
            destroy(new ChannelErrorEvent("Bad handshake (" +
                                          "HTTP-redirection is disabled" +
                                          ")"));
            return;
          }

          if (_attempt > MAX_REDIRECT_ATTEMPTS) {
            destroy(new ChannelErrorEvent("Bad handshake (" +
                                          "Too many redirect attempts" +
                                          ")"));
            return;
          }

          for (var i:Number = 1; i < head.length; i++) {
            m = /(\.):\s+(|.)/.exec(head[i]);
            if (m && m[1].toLowerCase() == "host") {
              handshake(URLParser.parse(m[2]));
              return;
            }
          }

          destroy(new ChannelErrorEvent("Bad handshake (" +
                                        "Expected 'host' in redirect" +
                                        ")"));
          return;

        default:
          destroy(new ChannelErrorEvent("Bad handshake (" +
                                        status + " " + body +
                                        ")"));
          return;
      }
    }

    // Internal method to keep track of no of channels that is associated
    // with this connection instance.
    internal function allocChannel() : void {
      _channelRefCount++;
    }


    // Decrease the reference count
    internal function deallocChannel(id:uint=0) : void {

      if (id != 0 && _openChannels) {
        delete _openChannels[id];
      }

      if (--_channelRefCount == 0) {
        destroy();
      }
    }


    // Request to open a channel. Return true if request went well, else
    // false.
    internal function requestOpen(request:OpenRequest) : Boolean {
      var id:uint = request.id;
      var queue:Array;

      if (_openChannels[id]) {
        return false;
      }

      if (_pendingOpenRequests[id]) {

        queue = _openWaitQueue[id] as Array;

        if (!queue) {
          _openWaitQueue[id] = queue = new Array();
        }

        queue.push(request);

      } else if (!_handshaked) {
        _pendingOpenRequests[id] = request;
      } else {
        _pendingOpenRequests[id] = request;
        writeBytes(request.frame);
        request.sent = true;

        try {
          flush();
        } catch (error:Error) {
          destroy(ChannelErrorEvent.fromError(error));
          return false;
        }
      }

      return true;
    }


    // Try to cancel an open request. Returns true on success else
    // false.
    internal function cancelOpen(request:OpenRequest) : Boolean {
      var id:uint = request.id;
      var queue:Array;
      var index:Number;

      if (request.sent) {
        return false;
      }

      queue = _openWaitQueue[id] as Array;

      if (_pendingOpenRequests[id]) {
        delete _pendingOpenRequests[id];

        if (queue != null && queue.length)  {
          _pendingOpenRequests[id] = queue.pop();
        }

        return true;
      }

      // Should not happen...
      if (queue == null) {
        return false;
      }

      index = queue.indexOf(request);

      if (index != -1) {
        queue.splice(index, 1);
        return true;
      }

      return false;
    }


    // Handles all incomming data.
    private function receiveHandler(event:ProgressEvent) : void {
      var channel:Channel = null;
      var size:uint;
      var id:uint;
      var op:Number;
      var flag:Number;
      var desc:Number;
      var payload:ByteArray;

      readBytes(_receiveBuffer, _receiveBuffer.length, bytesAvailable);

      while (_receiveBuffer.bytesAvailable >= Frame.HEADER_SIZE) {
        size = _receiveBuffer.readUnsignedShort();

        if (_receiveBuffer.bytesAvailable < (size - 2)) {
          _receiveBuffer.position -= 2;
          return;
        }

        id = _receiveBuffer.readUnsignedInt();
        desc = _receiveBuffer.readUnsignedByte();

        op = ((desc >> 1) & 0xf) >> 2;
        flag = (desc << 1 & 0xf) >> 1;

        if (size - Frame.HEADER_SIZE) {
          payload = new ByteArray();
          _receiveBuffer.readBytes(payload, 0, size - Frame.HEADER_SIZE);
        }

        switch (op) {

          case Frame.OPEN:
            processOpenFrame(id, flag, payload);
            break;

          case Frame.DATA:
            processDataFrame(id, flag, payload);
            break;

          case Frame.SIGNAL:
            processSignalFrame(id, flag, payload);
            break;
        }
      }

      if (_receiveBuffer.bytesAvailable == 0) {
        _receiveBuffer = new ByteArray();
      }
    }

    // process an open packet
    private function processOpenFrame(id:uint,
                                      flag:Number,
                                      payload:ByteArray) : void {
      var request:OpenRequest;
      var channel:Channel;
      var redirectid:uint;
      var event:Event;
      var message:String;

      request = OpenRequest(_pendingOpenRequests[id]);

      if (request == null) {
        event = new ChannelErrorEvent("Server sent invalid open packet");
        destroy(event);
        return;
      }

      channel = request.channel;

      switch (flag) {

        case Frame.OPEN_SUCCESS:

          if (payload && payload.length) {
            try {
              message = payload.readUTFBytes(payload.length);
            } catch (err:EOFError) {
              destroy(ChannelErrorEvent.fromError(err));
              return;
            }
          }

          _openChannels[id] = channel;

          channel.openSuccess(request.id, message);
          break;

        case Frame.OPEN_REDIRECT:

          if (payload == null || payload.length < 4) {
            destroy(new ChannelErrorEvent("Expected redirect channel from server"));
            return;
          }

          redirectid = payload.readUnsignedInt();

          if (payload.length > 4) {
            try {
              message = payload.readUTFBytes(payload.length - 4);
            } catch (err:EOFError) {
              destroy(ChannelErrorEvent.fromError(err));
              return;
            }
          }

          if (_openChannels[redirectid]) {
            destroy(new ChannelErrorEvent("Server redirected to open channel"));
            return;
          }

          _openChannels[redirectid] = channel;

          channel.openSuccess(redirectid, message);
          break;

        default:

          if (payload && payload.length) {
            try {
              message = payload.readUTFBytes(payload.length);
            } catch (err:EOFError) {
              destroy(ChannelErrorEvent.fromError(err));
              return;
            }
          }

          event = new ChannelErrorEvent(message || "Denied to open channel");
          channel.destroy(event);
          return;
      }

      if (_openWaitQueue[id] && _openWaitQueue[id].length) {

        // Destroy all pending request IF response wasn't a
        // redirected channel.
        if (flag == Frame.OPEN_REDIRECT && redirectid == id) {
          delete _pendingOpenRequests[id];

          event = new ChannelErrorEvent("Channel already open");

          while ((request = OpenRequest(_openWaitQueue[id].pop()))) {
            request.channel.destroy(event);
          }
          return;
        }

        request = _openWaitQueue[id].pop();
        _pendingOpenRequests[id] = request;

        if (!_openWaitQueue[id].length) {
          delete _openWaitQueue[id];
        }

        writeBytes(request.frame);
        request.sent = true;

        try {
          flush();
        } catch (error:Error) {
          destroy(ChannelErrorEvent.fromError(error));
        }

      } else {
        delete _pendingOpenRequests[id];
      }

    }

    // process a data packet
    private function processDataFrame(id:uint,
                                      flag:Number,
                                      payload:ByteArray) : void {
      var channel:Channel;
      var event:Event;
      var packet:Frame;

      if (payload == null || payload.length == 0) {
        destroy(new ChannelErrorEvent("Zero data packet sent received"));
        return;
      }

      if (id == BROADCAST_ALL) {
        for (var key:String in _openChannels) {
          event = new ChannelDataEvent(flag, payload);
          channel = Channel(_openChannels[key]);
          channel.dispatchEvent(event);
        }
      } else {
        channel = Channel(_openChannels[id]);

        if (channel == null) {
          return;
        }

        event = new ChannelDataEvent(flag, payload);

        channel.dispatchEvent(event);
      }
    }

    // process a signal packet
    private function processSignalFrame(id:uint,
                                        flag:Number,
                                        payload:ByteArray) : void {
      var event:Event = null;
      var channel:Channel;
      var packet:Frame;
      var message:String;

      if (payload && payload.length) {
        try {
          message = payload.readUTFBytes(payload.length);
        } catch (err:EOFError) {
          destroy(ChannelErrorEvent.fromError(err));
          return;
        }
      }

      switch (flag) {

        case Frame.SIG_EMIT:
          event = new ChannelSignalEvent(message);

          if (id == BROADCAST_ALL) {
            for (var key:String in _openChannels) {
              channel = Channel(_openChannels[key]);
              channel.dispatchEvent(event);
            }
          } else {
            channel = Channel(_openChannels[id]);
            if (channel == null) {
              return;
            }
            channel.dispatchEvent(event);
          }
          break;

        case Frame.SIG_END:

          event = new ChannelCloseEvent(message);

        default:

          if (event == null) {
            event = new ChannelErrorEvent(message);
          }

          if (id == BROADCAST_ALL) {
            destroy(event);
          } else {
            channel = Channel(_openChannels[id]);

            if (channel == null) {
              return;
            }

            if (channel.isClosing() == false) {
              // We havent closed our channel yet. We therefor need to send
              // and an ENDSIG in response to this packet.

              packet = new Frame(id, Frame.SIGNAL, Frame.SIG_END, payload);

              try {
                this.writeBytes(packet);
                this.flush();
              } catch (error:IOError) {
                destroy(ChannelErrorEvent.fromError(error));
                return;
              }
            } else {
              channel.destroy(event);
            }
          }
          break;
      }

    }

    private function securityErrorHandler(event:SecurityErrorEvent) : void {
      destroy(new ChannelErrorEvent("Security error"));
    }

    // Handles connection errors
    private function errorHandler(event:IOErrorEvent) : void {
      destroy(ChannelErrorEvent.fromEvent(event));
    }

    // Handles connection close
    private function closeHandler(event:Event) : void {
      destroy(new ChannelErrorEvent("Disconnected from server"));
    }

    // Finalize the Socket
    private function destroy(errorEvent:Event=null) : void {
      var event:Event = errorEvent;
      var pending:Dictionary = _pendingOpenRequests;
      var waitqueue:Dictionary = _openWaitQueue;
      var openchannels:Dictionary = _openChannels;
      var key:Object;
      var i:Number;
      var l:Number;
      var queue:Array;

      if (openchannels == null) {
        // Do not fire destroy multiple times.

        return;
      }

      removeEventListener(Event.CONNECT, connectHandler);
      removeEventListener(Event.CLOSE, closeHandler);
      removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);
      removeEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);
      removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
      removeEventListener(SecurityErrorEvent.SECURITY_ERROR,
                                  securityErrorHandler);

      _pendingOpenRequests = null;
      _openWaitQueue = null;
      _openChannels = null;

      if (event == null) {
        event = new ChannelErrorEvent("Unknown error");
      }

      if (pending != null) {
        for (key in pending) {
          OpenRequest(pending[key]).channel.destroy(event);
        }
      }

      if (waitqueue != null) {
        for (key in waitqueue) {
          queue = waitqueue[key] as Array;
          for (i = 0, l = queue.length; i < l; i++) {
            OpenRequest(queue[i]).channel.destroy(event);
          }
        }
      }

      for (key in openchannels) {
        Channel(openchannels[key]).destroy(event);
      }

      if (connected) {
        close();
      }

      if (availableSockets[_id]) {
        delete availableSockets[_id];
      }

    }

  }
}
