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
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;

  import hydna.net.OpenRequest;
  import hydna.net.Frame;
  import hydna.net.Channel;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelErrorEvent;
  import hydna.net.ChannelEmitEvent;
  import hydna.net.ChannelCloseEvent;

  // Internal wrapper around flash.net.Socket
  internal class Connection extends Socket {

    private static const BROADCAST_ADDR:Number = 0;

    private static const HANDSHAKE_SIZE:Number = 8;
    private static const HANDSHAKE_RESP_SIZE:Number = 5;

    private static const SUCCESS:Number = 0;
    private static const CUSTOM_ERR_CODE:Number = 0xf;

    private static var availableSockets:Dictionary;

    private var _connecting:Boolean = false;
    private var _handshaked:Boolean = false;

    private var _receiveBuffer:ByteArray;
    private var _uri:String;
    private var _host:String;
    private var _port:Number;

    private var _pendingOpenRequests:Dictionary;
    private var _openChannels:Dictionary;
    private var _openWaitQueue:Dictionary;

    private var _streamRefCount:Number = 0;

    {
      availableSockets = new Dictionary();
    }

    // Return an available socket or create a new one.
    internal static function getSocket(host:String, port:Number) : Connection {
      var uri:String = "hydna:" + host + ":" + port;
      var socket:Connection;

      if (availableSockets[uri]) {
        socket = availableSockets[uri];
      } else {
        socket = new Connection(uri, host, port);
        availableSockets[uri] = socket;
      }

      return socket;
    }

    /**
     *  Initializes a new Channel instance
     */
    public function Connection(uri:String, host:String, port:Number) {
      super();

      _uri = uri;
      _host = host;
      _port = port;

      _receiveBuffer = new ByteArray();

      _pendingOpenRequests = new Dictionary();
      _openChannels = new Dictionary();
      _openWaitQueue = new Dictionary();

      addEventListener(Event.CONNECT, connectHandler);
      addEventListener(Event.CLOSE, closeHandler);
      addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
      addEventListener(SecurityErrorEvent.SECURITY_ERROR,
                       securityErrorHandler);
    }

    internal function get uri() : String {
      return _uri;
    }

    internal function get handshaked() : Boolean {
      return _handshaked;
    }

    // Internal method to keep track of no of streams that is associated
    // with this connection instance.
    internal function allocChannel() : void {
      _streamRefCount++;
    }

    // Decrease the reference count
    internal function deallocChannel(ch:uint=0) : void {

      if (ch != 0 && _openChannels) {
        delete _openChannels[ch];
      }

      if (--_streamRefCount == 0) {
        destroy();
      }
    }

    // Request to open a stream. Return true if request went well, else
    // false.
    internal function requestOpen(request:OpenRequest) : Boolean {
      var ch:uint = request.ch;
      var queue:Array;

      if (_openChannels[ch]) {
        return false;
      }

      if (_pendingOpenRequests[ch]) {

        queue = _openWaitQueue[ch] as Array;

        if (!queue) {
          _openWaitQueue[ch] = queue = new Array();
        }

        queue.push(request);

      } else if (!_handshaked) {
        _pendingOpenRequests[ch] = request;
        if (!_connecting) {
          _connecting = true;
          connect(_host, _port);
        }
      } else {
        _pendingOpenRequests[ch] = request;
        writeBytes(request.packet);
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
      var ch:uint = request.ch;
      var queue:Array;
      var index:Number;

      if (request.sent) {
        return false;
      }

      queue = _openWaitQueue[ch] as Array;

      if (_pendingOpenRequests[ch]) {
        delete _pendingOpenRequests[ch];

        if (queue != null && queue.length)  {
          _pendingOpenRequests[ch] = queue.pop();
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

    //  Send a handshake packet and wait for a handshake
    // response packet in return.
    private function connectHandler(event:Event) : void {

      addEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);

      writeMultiByte("DNA1", "us-acii");
      writeByte(_host.length);
      writeMultiByte(_host, "us-ascii");

      try {
        flush();
      } catch (error:Error) {
        destroy(ChannelErrorEvent.fromError(error));
      }
    }

    // Handle the Handshake response packet.
    private function handshakeHandler(event:ProgressEvent) : void {
      var sentRequestCount:Number = 0;
      var request:OpenRequest;
      var code:Number;
      var errevent:Event;

      readBytes(_receiveBuffer, _receiveBuffer.length, bytesAvailable);

      if (_receiveBuffer.length < HANDSHAKE_RESP_SIZE) {
        return;
      } else if (_receiveBuffer.length > HANDSHAKE_RESP_SIZE) {
        errevent = new ChannelErrorEvent("Server responed with bad handshake");
        dispatchEvent(errevent);
        return;
      }

      if (_receiveBuffer.readMultiByte(HANDSHAKE_RESP_SIZE - 1, "us-acii")
          !== "DNA1") {
        errevent = new ChannelErrorEvent("Server responed with bad handshake");
        dispatchEvent(errevent);
        return;
      }

      if ((code = _receiveBuffer.readByte()) > 0) {
        errevent = ChannelErrorEvent.fromHandshakeError(code);
        dispatchEvent(errevent);
        return;
      }

      _handshaked = true;
      _connecting = false;

      _receiveBuffer = new ByteArray();
      removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);
      addEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);

      for (var key:Object in _pendingOpenRequests) {
        request = OpenRequest(_pendingOpenRequests[key]);
        writeBytes(request.packet);
        request.sent = true;
      }

      try {
        flush();
      } catch (error:Error) {
        destroy(ChannelErrorEvent.fromError(error));
      }
    }

    // Handles all incomming data.
    private function receiveHandler(event:ProgressEvent) : void {
      var stream:Channel = null;
      var size:uint;
      var ch:uint;
      var op:Number;
      var flag:Number;
      var payload:ByteArray;

      readBytes(_receiveBuffer, _receiveBuffer.length, bytesAvailable);

      while (_receiveBuffer.bytesAvailable >= Frame.HEADER_SIZE) {
        size = _receiveBuffer.readUnsignedShort();

        if (_receiveBuffer.bytesAvailable < (size - 2)) {
          _receiveBuffer.position -= 2;
          return;
        }

        _receiveBuffer.readUnsignedByte(); // Reserved
        ch = _receiveBuffer.readUnsignedInt();
        op = _receiveBuffer.readUnsignedByte();
        flag = (op & 0xf);

        if (size - Frame.HEADER_SIZE) {
          payload = new ByteArray();
          _receiveBuffer.readBytes(payload, 0, size - Frame.HEADER_SIZE);
        }

        switch ((op >> 4)) {

          case Frame.OPEN:
            processOpenFrame(ch, flag, payload);
            break;

          case Frame.DATA:
            processDataFrame(ch, flag, payload);
            break;

          case Frame.SIGNAL:
            processSignalFrame(ch, flag, payload);
            break;
        }
      }

      if (_receiveBuffer.bytesAvailable == 0) {
        _receiveBuffer = new ByteArray();
      }
    }

    // process an open packet
    private function processOpenFrame( ch:uint
                                      , flag:Number
                                      , payload:ByteArray) : void {
      var request:OpenRequest;
      var stream:Channel;
      var redirectch:uint;
      var event:Event;

      request = OpenRequest(_pendingOpenRequests[ch]);

      if (request == null) {
        event = new ChannelErrorEvent("Server sent invalid open packet");
        destroy(event);
        return;
      }

      stream = request.stream;

      switch (flag) {

        case Frame.OPEN_SUCCESS:
          _openChannels[ch] = stream;
          stream.openSuccess(request.ch);
          break;

        case Frame.OPEN_REDIRECT:

          if (payload == null || payload.length < 4) {
            destroy(new ChannelErrorEvent("Expected redirect channel from server"));
            return;
          }

          redirectch = payload.readUnsignedInt();

          if (_openChannels[redirectch]) {
            destroy(new ChannelErrorEvent("Server redirected to open stream"));
            return;
          }

          _openChannels[redirectch] = stream;
          stream.openSuccess(redirectch);
          break;

        case Frame.OPEN_FAIL_NA:
        case Frame.OPEN_FAIL_MODE:
        case Frame.OPEN_FAIL_PROTOCOL:
        case Frame.OPEN_FAIL_HOST:
        case Frame.OPEN_FAIL_AUTH:
        case Frame.OPEN_FAIL_SERVICE_NA:
        case Frame.OPEN_FAIL_SERVICE_ERR:
        case Frame.OPEN_FAIL_OTHER:
          event = ChannelErrorEvent.fromOpenError(flag, payload);
          stream.destroy(event);
          break;

        default:
          destroy(new ChannelErrorEvent("Server sent an unknown packet flag"));
          return;
      }

      if (_openWaitQueue[ch] && _openWaitQueue[ch].length) {

        // Destroy all pending request IF response wasn't a
        // redirected stream.
        if (flag == Frame.OPEN_REDIRECT && redirectch == ch) {
          delete _pendingOpenRequests[ch];

          event = new ChannelErrorEvent("Channel already open");

          while ((request = OpenRequest(_openWaitQueue[ch].pop()))) {
            request.stream.destroy(event);
          }
          return;
        }

        request = _openWaitQueue[ch].pop();
        _pendingOpenRequests[ch] = request;

        if (!_openWaitQueue[ch].length) {
          delete _openWaitQueue[ch];
        }

        writeBytes(request.packet);
        request.sent = true;

        try {
          flush();
        } catch (error:Error) {
          destroy(ChannelErrorEvent.fromError(error));
        }

      } else {
        delete _pendingOpenRequests[ch];
      }

    }

    // process a data packet
    private function processDataFrame( ch:uint
                                      , flag:Number
                                      , payload:ByteArray) : void {
      var stream:Channel;
      var event:Event;
      var packet:Frame;

      if (payload == null || payload.length == 0) {
        destroy(new ChannelErrorEvent("Zero data packet sent received"));
        return;
      }

      if (ch == BROADCAST_ADDR) {
        for (var key:String in _openChannels) {
          event = new ChannelDataEvent(flag, payload);
          stream = Channel(_openChannels[key]);
          stream.dispatchEvent(event);
        }
      } else {
        stream = Channel(_openChannels[ch]);

        if (stream == null) {
          destroy(new ChannelErrorEvent("Frame sent to unknown stream"));
          return;
        }

        event = new ChannelDataEvent(flag, payload);

        stream.dispatchEvent(event);
      }
    }

    // process a signal packet
    private function processSignalFrame( ch:uint
                                        , flag:Number
                                        , payload:ByteArray) : void {
      var event:Event = null;
      var stream:Channel;
      var packet:Frame;

      switch (flag) {

        case Frame.SIG_EMIT:

          if (ch == BROADCAST_ADDR) {
            for (var key:String in _openChannels) {
              event = new ChannelEmitEvent(payload);
              stream = Channel(_openChannels[key]);
              stream.dispatchEvent(event);
            }
          } else {
            event = new ChannelEmitEvent(payload);

            stream = Channel(_openChannels[ch]);

            if (stream == null) {
              destroy(new ChannelErrorEvent("Frame sent to unknown stream"));
              return;
            }

            stream.dispatchEvent(event);
          }
          break;

        case Frame.SIG_END:

          event = new ChannelCloseEvent(payload);

        case Frame.SIG_ERR_PROTOCOL:
        case Frame.SIG_ERR_OPERATION:
        case Frame.SIG_ERR_LIMIT:
        case Frame.SIG_ERR_SERVER:
        case Frame.SIG_ERR_VIOLATION:
        case Frame.SIG_ERR_OTHER:

          if (event == null) {
            event = ChannelErrorEvent.fromSigError(flag, payload);
          }

          if (ch == BROADCAST_ADDR) {
            destroy(event);
          } else {
            stream = Channel(_openChannels[ch]);

            if (stream == null) {
              destroy(new ChannelErrorEvent("Received unknown channel"));
              return;
            }

            if (stream.isClosing() == false) {
              // We havent closed our stream yet. We therefor need to send
              // and an ENDSIG in response to this packet.

              packet = new Frame(ch, Frame.SIGNAL, Frame.SIG_END, payload);

              try {
                this.writeBytes(packet);
                this.flush();
              } catch (error:IOError) {
                destroy(ChannelErrorEvent.fromError(error));
                return;
              }
            } else {
              stream.destroy(event);
            }
          }
          break;

        default:
          destroy(new ChannelErrorEvent("Received unknown packet flag"));
          break;

      }

    }

    private function securityErrorHandler(event:SecurityErrorEvent) : void {
      destroy(new ChannelErrorEvent("Security error"));
    }

    // Handles socket errors
    private function errorHandler(event:IOErrorEvent) : void {
      destroy(ChannelErrorEvent.fromEvent(event));
    }

    // Handles socket close
    private function closeHandler(event:Event) : void {
      destroy(new ChannelErrorEvent("Disconnected from server"));
    }

    // Finalize the Socket
    private function destroy(errorEvent:Event=null) : void {
      var event:Event = errorEvent;
      var pending:Dictionary = _pendingOpenRequests;
      var waitqueue:Dictionary = _openWaitQueue;
      var openstreams:Dictionary = _openChannels;
      var key:Object;
      var i:Number;
      var l:Number;
      var queue:Array;

      if (openstreams == null) {
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
          OpenRequest(pending[key]).stream.destroy(event);
        }
      }

      if (waitqueue != null) {
        for (key in waitqueue) {
          queue = waitqueue[key] as Array;
          for (i = 0, l = queue.length; i < l; i++) {
            OpenRequest(queue[i]).stream.destroy(event);
          }
        }
      }

      for (key in openstreams) {
        Channel(openstreams[key]).destroy(event);
      }

      if (connected) {
        close();
      }


      if (availableSockets[_uri]) {
        delete availableSockets[_uri];
      }

    }

  }
}