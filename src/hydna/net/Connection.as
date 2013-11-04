// Connection.as

/**
 *        Copyright 2010-2013 Hydna AB. All rights reserved.
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

    private static const DEFAULT_PORT:Number = 80;

    private static const BROADCAST_ALL:Number = 0;

    private static const HANDSHAKE_SIZE:Number = 8;
    private static const HANDSHAKE_RESP_SIZE:Number = 5;

    private static const SUCCESS:Number = 0;
    private static const CUSTOM_ERR_CODE:Number = 0xf;

    private static var availableSockets:Dictionary;

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
    private var _openChannelsByPath:Dictionary;

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
      _openChannelsByPath = new Dictionary();

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
      packet[4] = "\r\n";

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

          flushRequests();

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
    internal function deallocChannel(path:String, id:Number) : void {

      if (path != null && _openChannelsByPath) {
        delete _openChannelsByPath[path];
      }

      if (id != 0 && _openChannels) {
        delete _openChannels[id];
      }

      if (--_channelRefCount == 0) {
        destroy();
      }
    }


    internal function allocOpenRequest(request:OpenRequest) : void {
      _pendingOpenRequests[request.path] = request;
    }


    internal function deallocOpenRequest(request:OpenRequest) : void {
      delete _pendingOpenRequests[request.path];
    }


    internal function flushRequests(specificRequest:OpenRequest=null) : void {
      var request:OpenRequest;

      if (specificRequest) {
        if (specificRequest.id != 0) {
          writeBytes(specificRequest.openFrame);
          specificRequest.sent = true;
        } else {
          writeBytes(specificRequest.resolveFrame);
        }
      } else {
        for (var key:Object in _pendingOpenRequests) {
          request = OpenRequest(_pendingOpenRequests[key]);
          writeBytes(request.resolveFrame);
          request.sent = true;
        }
      }

      try {
        flush();
      } catch (error:Error) {
        destroy(ChannelErrorEvent.fromError(error));
      }

    }


    // Request to open a channel. Return true if request went well, else
    // false.
    internal function requestOpen(request:OpenRequest) : Boolean {
      var path:String = request.path;
      var channel:Channel;
      var currentRequest:OpenRequest;
      var queue:Array;

      if ((channel = Channel(_openChannelsByPath[path])) != null) {
        return channel.setPendingOpenRequest(request);
      } else if ((currentRequest = OpenRequest(_pendingOpenRequests[path]))) {
        return currentRequest.channel.setPendingOpenRequest(request);
      } else {

        allocOpenRequest(request);

        if (_handshaked) {
          flushRequests(request);
        }
      }

      return true;
    }


    // Try to cancel an open request. Returns true on success else
    // false.
    internal function cancelOpen(request:OpenRequest) : Boolean {

      if (request.sent) {
        return false;
      }

      deallocOpenRequest(request);

      return true;
    }


    // Handles all incomming data.
    private function receiveHandler(event:ProgressEvent) : void {
      var channel:Channel = null;
      var size:uint;
      var id:uint;
      var op:Number;
      var flag:Number;
      var ctype:Number;
      var desc:Number;
      var data:ByteArray;

      readBytes(_receiveBuffer, _receiveBuffer.length, bytesAvailable);

      while (_receiveBuffer.bytesAvailable >= Frame.HEADER_SIZE) {
        size = _receiveBuffer.readUnsignedShort();

        if (_receiveBuffer.bytesAvailable < (size - 2)) {
          _receiveBuffer.position -= 2;
          return;
        }

        data = null;

        id = _receiveBuffer.readUnsignedInt();
        desc = _receiveBuffer.readUnsignedByte();

        ctype = (desc & Frame.CTYPE_BITMASK) >> Frame.CTYPE_BITPOS;
        op = (desc & Frame.OP_BITMASK) >> Frame.OP_BITPOS;
        flag = (desc & Frame.FLAG_BITMASK);

        if (size - Frame.HEADER_SIZE) {
          data = new ByteArray();
          _receiveBuffer.readBytes(data, 0, size - Frame.HEADER_SIZE);
        }

        switch (op) {

          case Frame.KEEPALIVE:
            break;

          case Frame.OPEN:
            processOpenFrame(id, ctype, flag, data);
            break;

          case Frame.DATA:
            processDataFrame(id, ctype, flag, data);
            break;

          case Frame.SIGNAL:
            processSignalFrame(id, ctype, flag, data);
            break;

          case Frame.RESOLVE:
            processResolveFrame(id, ctype, flag, data);
            break;
        }
      }

      if (_receiveBuffer.bytesAvailable == 0) {
        _receiveBuffer = new ByteArray();
      }
    }

    // process an open packet
    private function processOpenFrame(id:uint,
                                      ctype:Number,
                                      flag:Number,
                                      data:ByteArray) : void {
      var request:OpenRequest;
      var channel:Channel;
      var event:Event;

      if ((request = getOpenRequestById(id)) == null) {
        event = new ChannelErrorEvent("Server sent invalid open packet");
        destroy(event);
        return;
      }

      channel = request.channel;

      switch (flag) {

        case Frame.OPEN_SUCCESS:
          _openChannels[id] = channel;
          channel.openSuccess(request.id, ctype, data);
          break;

        default:
          event = ChannelErrorEvent.fromData(ctype,
                                             data,
                                             "Denied to open channel");
          channel.destroy(event);
          return;
      }

      deallocOpenRequest(request);
    }


    // process a data packet
    private function processDataFrame(id:uint,
                                      ctype:Number,
                                      flag:Number,
                                      data:ByteArray) : void {
      var channel:Channel;
      var event:Event;

      if (data == null || data.length == 0) {
        destroy(new ChannelErrorEvent("Zero data packet sent received"));
        return;
      }

      if (id == BROADCAST_ALL) {
        for (var key:String in _openChannels) {
          event = new ChannelDataEvent(ctype, data, flag);
          channel = Channel(_openChannels[key]);
          channel.dispatchEvent(event);
        }
      } else {
        channel = Channel(_openChannels[id]);

        if (channel == null) {
          return;
        }

        event = new ChannelDataEvent(ctype, data, flag);

        channel.dispatchEvent(event);
      }
    }


    // process a signal packet
    private function processSignalFrame(id:uint,
                                        ctype:Number,
                                        flag:Number,
                                        data:ByteArray) : void {
      var event:Event = null;
      var request:OpenRequest;
      var channel:Channel;
      var packet:Frame;

      switch (flag) {

        case Frame.SIG_EMIT:
          event = new ChannelSignalEvent(ctype, data);

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

          event = new ChannelCloseEvent(ctype, data);

        default:

          if (event == null) {
            event = ChannelErrorEvent.fromData(ctype, data);
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

              packet = new Frame(id, Frame.SIGNAL, Frame.SIG_END);

              try {
                this.writeBytes(packet);
                this.flush();
              } catch (error:IOError) {
                destroy(ChannelErrorEvent.fromError(error));
                return;
              }
            }

            channel.destroy(event);
          }
          break;
      }

    }


    private function processResolveFrame(id:uint,
                                         ctype:Number,
                                         flag:Number,
                                         data:ByteArray) : void {
      var request:OpenRequest;
      var event:Event;

      if ((request = getOpenRequestByPath(ctype, data))) {
        if (flag == Frame.OPEN_SUCCESS) {
          request.id = id;
          flushRequests(request);
        } else {
          event = new ChannelErrorEvent("Unable to resolve channel path");
          request.channel.destroy(event);
        }
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


    private function getOpenRequestById(id:uint) : OpenRequest {
      var requests:Dictionary = _pendingOpenRequests;
      var request:OpenRequest;
      var key:Object;
      
      for (key in requests) {
        request = OpenRequest(requests[key]);
        if (request.id == id) {
          return request;
        }
      }

      return null;
    }


    private function getOpenRequestByPath(ctype:Number, data:ByteArray)
      : OpenRequest {
      var path:String;
      var oldpos:uint;

      if (ctype == Frame.PAYLOAD_UTF) {
        try {
          oldpos = data.position;
          path = data.readUTFBytes(data.length);
          return OpenRequest(_pendingOpenRequests[path]);
        } catch (err:EOFError) {
        } finally {
          data.position = oldpos;
        }
      }

      return null;
    }


    // Finalize the Socket
    private function destroy(errorEvent:Event=null) : void {
      var event:Event = errorEvent;
      var pending:Dictionary = _pendingOpenRequests;
      var openchannels:Dictionary = _openChannelsByPath;
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
      _openChannelsByPath = null;
      _openChannels = null;

      if (event == null) {
        event = new ChannelErrorEvent("Unknown error");
      }

      if (pending != null) {
        for (key in pending) {
          OpenRequest(pending[key]).channel.destroy(event);
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
