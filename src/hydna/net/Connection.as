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
  import flash.events.ErrorEvent;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.errors.IOError;
  import flash.errors.EOFError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;
  import flash.utils.getDefinitionByName;


  // Internal wrapper around flash.net.Socket
  internal class Connection {

    private static const PROTOCOL_VERSION:String = "winksock/1";

    private static const DEFAULT_PORT:Number = 80;
    private static const DEFAULT_SECURE_PORT:Number = 443;

    private static const BROADCAST_ALL:Number = 0;

    private static const HANDSHAKE_SIZE:Number = 8;
    private static const HANDSHAKE_RESP_SIZE:Number = 5;

    private static const SUCCESS:Number = 0;
    private static const CUSTOM_ERR_CODE:Number = 0x7;

    private static const UNSECURE_CLASS:String = "flash.net.Socket";
    private static const SECURE_CLASS:String = "flash.net.SecureSocket";

    private static var connectionCollections:Dictionary;

    private var _handshakeBuffer:String;

    private var _connecting:Boolean = false;
    private var _handshaked:Boolean = false;

    private var _receiveBuffer:ByteArray;
    private var _url:String;

    private var _socket:Socket;
    private var _channels:Dictionary;
    private var _routes:Dictionary;
    private var _refcount:Number = 0;


    {
      connectionCollections = new Dictionary();
    }

    /***
      Return an available connection or create a new one.
    */
    internal static function getConnection (instance:Channel,
                                            urlobj:Object) : Connection {
      var connurl:String;
      var connection:Connection;

      connurl = createConnectionUrl(urlobj);

      if (connectionCollections[connurl]) {
        for each (var conn:Connection in connectionCollections[connurl]) {
          if (conn.containsChannel(urlobj.path) == false) {
            connection = conn;
            break;
          }
        }
      }

      if (connection == null) {
        connection = new Connection(connurl);
        if (!connectionCollections[connurl]) {
          connectionCollections[connurl] = new Array();
        }
        connectionCollections[connurl].push(connection);
      }

      connection.createChannel(instance, urlobj.path);

      return connection;
    }


    internal static function hasTlsSupport () : Boolean {
      var SecureSocket:Class;

      try {
        SecureSocket = getDefinitionByName(SECURE_CLASS) as Class;
        return Boolean(SecureSocket.isSupported);
      } catch (err:ReferenceError) {
      }

      return false;
    }


    internal static function createConnectionUrl (urlobj:Object) : String {
      var result:Array = new Array();

      result = [urlobj.protocol, '://', urlobj.host];

      if (urlobj.port) {
        result.push(':' + urlobj.port);
      }

      return result.join('');
    }


    /**
     *  Initializes a new Channel instance
     */
    public function Connection(url:String) {
      var SocketClass:Class;

      _url = url;

      if (isSecure) {
        SocketClass = getDefinitionByName(SECURE_CLASS) as Class;
      } else {
        SocketClass = getDefinitionByName(UNSECURE_CLASS) as Class;
      }

      _socket = new SocketClass();

      _socket.addEventListener(Event.CLOSE, closeHandler);
      _socket.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
      _socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,
                               securityErrorHandler);

      _receiveBuffer = new ByteArray();
      _channels = new Dictionary();
      _routes = new Dictionary();

    }


    internal function get isSecure () : Boolean {
      return /^https:/.test(_url);
    }


    internal function get url () : String {
      return _url;
    }


    private function get handshaked () : Boolean {
      return _handshaked;
    }


    private function containsChannel (path:String) : Boolean {
      return !!(_channels[path]);
    }


    private function handshake () : void {
      var urlobj:Object;

      if (_connecting == true) {
        throw new Error("Already connecting");
      }

      _socket.addEventListener(Event.CONNECT, connectHandler);
      _socket.addEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);

      urlobj = URLParser.parse(_url);

      _handshakeBuffer = "";

      _connecting = true;

      _socket.connect(urlobj.host, urlobj.port ||
                                     (isSecure ? DEFAULT_SECURE_PORT
                                               : DEFAULT_PORT));
    }


    private function connectHandler(event:Event) : void {
      var packet:Array = new Array();
      var urlobj:Object;
      
      _socket.removeEventListener(Event.CONNECT, connectHandler);

      urlobj = URLParser.parse(_url);

      // TODO: Initialize a handshake timeout handler

      packet[0] = "GET / HTTP/1.1";
      packet[1] = "Connection: Upgrade";
      packet[2] = "Upgrade: " + PROTOCOL_VERSION;
      packet[3] = "Host: " + urlobj.host;
      packet[4] = "\r\n";

      try {
        _socket.writeMultiByte(packet.join("\r\n"), "us-ascii");
        _socket.flush();
      } catch (error:Error) {
        destroyWithError(error);
        return;
      }
    }


    private function handshakeHandler (event:ProgressEvent) : void {
      var frame:Frame;      
      var path:ByteArray;
      var buffer:String;
      var splitted:Array;
      var head:Array;
      var body:String;
      var headers:Array;
      var m:Object;
      var status:Number;

      buffer = _socket.readUTFBytes(_socket.bytesAvailable);

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

      _socket.removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);

      m = /HTTP\/1\.1\s(\d+)/.exec(head[0]);

      if (!m) {
        destroyWithError(new Error("Bad handshake (HTTP decoding)"));
        return;
      }

      if (isNaN(status = int(m[1]))) {
        destroyWithError(new Error("Bad handshake (HTTP status missing)"));
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
          _socket.addEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);

          for each (var channel:Channel in _channels) {
            if (channel.resolved == false) {
              channel.resolved = true;
              path = new ByteArray();
              path.writeUTFBytes(channel.path);
              frame = new Frame(0, Frame.PAYLOAD_UTF, Frame.RESOLVE, 0, path);
              writeFrame(frame);
            }
          }
          return;

        default:
          destroyWithError(new Error("Bad handshake (" +
                                      status + " " +
                                      body + ")"));
          return;
      }
    }


    internal function createChannel (instance:Channel, path:String) : void {
      var frame:Frame;
      var data:ByteArray;

      if (path in this._channels) {
        throw new Error("Channel already created");
      }

      _channels[path] = instance;
      _refcount++;

      if (_handshaked) {
        instance.resolved = true;
        data = new ByteArray();
        data.writeUTFBytes(path);
        frame = new Frame(0, Frame.PAYLOAD_UTF, Frame.RESOLVE, 0, data);
        writeFrame(frame);
      } else if (_connecting == false) {
        handshake();
      }
    }


    internal function destroyChannel (instance:Channel,
                                      isError:Boolean,
                                      ctype:Number,
                                      data:ByteArray,
                                      defaultMessage:String = null) : void {
      var event:Event;

      if (instance.path == null) {
        return;
      }

      delete _channels[instance.path];

      if (isNaN(instance.ptr) == false) {
        delete _routes[instance.ptr];
      }

      if (isError) {
        event = ChannelErrorEvent.fromData(ctype, data, defaultMessage);
      } else {
        event = new ChannelCloseEvent(ctype, data);
      }

      try {
        instance.destroyHandler(event);
      } catch (error:Error) {
      } finally {
        _refcount--;
        if (_refcount == 0) {
          destroy();
        }
      }
    }


    private function dispatchChannelEvent (target:Channel, event:Event) : void {
      try {
        target.dispatchEvent(event);
      } catch (error:Error) {
      }
    }


    internal function writeFrame (frame:Frame) : Boolean {
      try {
        _socket.writeBytes(frame);
        _socket.flush();
      } catch (error:IOError) {
        destroyWithError(error);
        return true;
      }
      return false;
    }
 
 
    // Handles all incomming data.
    private function receiveHandler (event:ProgressEvent) : void {
      var size:uint;
      var ptr:uint;
      var op:Number;
      var flag:Number;
      var ctype:Number;
      var desc:Number;
      var data:ByteArray;

      _socket.readBytes(_receiveBuffer,
                        _receiveBuffer.length,
                        _socket.bytesAvailable);

      while (_receiveBuffer.bytesAvailable >= 2) {
        size = _receiveBuffer.readUnsignedShort();

        if (_receiveBuffer.bytesAvailable < size) {
          _receiveBuffer.position -= 2;
          return;
        }

        data = null;

        ptr = _receiveBuffer.readUnsignedInt();
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
            processOpenFrame(ptr, ctype, flag, data);
            break;

          case Frame.DATA:
            processDataFrame(ptr, ctype, flag, data);
            break;

          case Frame.SIGNAL:
            processSignalFrame(ptr, ctype, flag, data);
            break;

          case Frame.RESOLVE:
            processResolveFrame(ptr, ctype, flag, data);
            break;
        }
      }

      if (_receiveBuffer.bytesAvailable == 0) {
        _receiveBuffer = new ByteArray();
      }
    }


    // process an open packet
    private function processOpenFrame (ptr:uint,
                                       ctype:Number,
                                       flag:Number,
                                       data:ByteArray) : void {
      var channel:Channel;

      if ((channel = _routes[ptr] as Channel) == null) {
        destroyWithError(new Error("Server sent invalid open packet"));
        return;
      }

      if (channel.connected) {
        destroyWithError(new Error("Server sent open to an open channel"));
        return;
      }

      switch (flag) {

        case Frame.OPEN_SUCCESS:
          channel.openHandler(new ChannelOpenEvent(ctype, data));
          break;

        default:
          destroyChannel(channel, true, ctype, data, "Denied to open channel");
          return;
      }
    }


    // process a data packet
    private function processDataFrame (ptr:uint,
                                       ctype:Number,
                                       flag:Number,
                                       data:ByteArray) : void {
      var channel:Channel;

      if (data == null || data.length == 0) {
        destroyWithError(new Error("Zero data packet sent received"));
        return;
      }

      if (ptr == BROADCAST_ALL) {
        for each (channel in _routes) {
          if (channel.readable) {
            dispatchChannelEvent(channel,
                                 new ChannelDataEvent(ctype, data, flag));
          }
        }
      } else {
        if ((channel = Channel(_routes[ptr])) == null) {
          return;
        }

        if (channel.readable) {
          dispatchChannelEvent(channel,
                               new ChannelDataEvent(ctype, data, flag));
        }
      }
    }


    // process a signal packet
    private function processSignalFrame (ptr:uint,
                                         ctype:Number,
                                         flag:Number,
                                         data:ByteArray) : void {
      var channel:Channel;
      var frame:Frame;

      switch (flag) {

        case Frame.SIG_EMIT:

          if (ptr == BROADCAST_ALL) {

            for each (channel in _routes) {
              if (channel.connected) {
                dispatchChannelEvent(channel,
                                     new ChannelSignalEvent(ctype, data));
              }
            }

          } else {
            if ((channel = Channel(_routes[ptr])) == null) {
              return;
            }

            if (channel.connected) {
              dispatchChannelEvent(channel,
                                   new ChannelSignalEvent(ctype, data));
            }
          }
          break;

        case Frame.SIG_END:

          if (ptr == BROADCAST_ALL) {
            return destroyWithEndSig(ctype, data);
          }

          if ((channel = Channel(_routes[ptr])) == null) {
            return;
          }

          if (channel.connected == false) {
            return;
          }

          if (channel.closing == false) {
            // We havent closed our channel yet. We therefor need to send
            // and an ENDSIG in response to this packet.

            frame = new Frame(ptr, Frame.SIGNAL, Frame.SIG_END);
            if (writeFrame(frame) == false) {
              destroyChannel(channel, false, ctype, data);
            }
          } else {
            destroyChannel(channel, false, ctype, data);
          }
          break;
        
        default:

          if (ptr == BROADCAST_ALL) {
            return destroyWithErrorData(ctype, data);
          }

          if ((channel = Channel(_routes[ptr])) == null) {
            return;
          }

          if (channel.connected == false) {
            return;
          }

          if (channel.closing == false) {
            // We havent closed our channel yet. We therefor need to send
            // and an ENDSIG in response to this packet.

            frame = new Frame(ptr, Frame.SIGNAL, Frame.SIG_END);
            if (writeFrame(frame) == false) {
              destroyChannel(channel, true, ctype, data);
            }
          } else {
            destroyChannel(channel, true, ctype, data);
          }
          break;
      }

    }


    private function processResolveFrame (ptr:uint,
                                          ctype:Number,
                                          flag:Number,
                                          data:ByteArray) : void {
      var channel:Channel;
      var frame:Frame;

      if ((channel = getChannelByPath(ctype, data)) == null) {
        return;
      }

      if (channel.closing) {
        destroyChannel(channel, false, 0, null, null);
        return;
      }

      if (flag != Frame.OPEN_SUCCESS) {
        destroyChannel(channel, true, 0, null, "Unable to resolve channel path");
        return;
      }

      _routes[ptr] = channel;
      channel.ptr = ptr;

      frame = new Frame(ptr,
                        channel.openCType,
                        Frame.OPEN,
                        channel.mode,
                        channel.openData);

      writeFrame(frame);
    }


    private function securityErrorHandler (event:SecurityErrorEvent) : void {
      destroyWithErrorEvent(event);
    }


    // Handles connection errors
    private function errorHandler (event:IOErrorEvent) : void {
      destroyWithErrorEvent(event);
    }


    // Handles connection close
    private function closeHandler (event:Event) : void {
      destroyWithErrorEvent(new ChannelErrorEvent("Disconnected from server"));
    }


    private function getChannelByPath (ctype:Number, data:ByteArray)
      : Channel {
      var path:String;
      var oldpos:uint;

      if (ctype == Frame.PAYLOAD_UTF) {
        try {
          oldpos = data.position;
          path = data.readUTFBytes(data.length);
          return Channel(_channels[path]);
        } catch (err:EOFError) {
        } finally {
          data.position = oldpos;
        }
      }

      return null;
    }


    private function destroyWithEndSig (ctype:Number, data:ByteArray) : void {
      var channels:Dictionary = _channels;
      var event:ChannelCloseEvent;
      var dataCopy:ByteArray;
      var channel:Channel;

      destroy();

      for (var key:String in channels) {
        if ((channel = Channel(channels[key])) != null) {
          dataCopy = new ByteArray();
          dataCopy.writeBytes(data);
          event = new ChannelCloseEvent(ctype, dataCopy);
          channel.destroyHandler(event);
        }
      }
    }


    private function destroyWithErrorData (ctype:Number, data:ByteArray) : void {
      var channels:Dictionary = _channels;
      var event:ChannelErrorEvent;
      var channel:Channel;

      destroy();

      for (var key:String in channels) {
        if ((channel = Channel(channels[key])) != null) {
          event = ChannelErrorEvent.fromData(ctype, data);
          channel.destroyHandler(event);
        }
      }
    }


    private function destroyWithError (error:Error) : void {
      var channels:Dictionary = _channels;
      var event:ChannelErrorEvent;
      var channel:Channel;

      destroy();

      for (var key:String in channels) {
        if ((channel = Channel(channels[key])) != null) {
          event = ChannelErrorEvent.fromError(error);
          channel.destroyHandler(event);
        }
      }
    }


    private function destroyWithErrorEvent (errorEvent:ErrorEvent) : void {
      var channels:Dictionary = _channels;
      var event:ChannelErrorEvent;
      var channel:Channel;

      destroy();

      for (var key:String in channels) {
        if ((channel = Channel(channels[key])) != null) {
          event = ChannelErrorEvent.fromEvent(errorEvent);
          channel.destroyHandler(event);
        }
      }
    }


    private function destroy () : void {
      var idx:Number;

      if (_socket != null) {
        _socket.removeEventListener(Event.CONNECT, connectHandler);
        _socket.removeEventListener(Event.CLOSE, closeHandler);
        _socket.removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);
        _socket.removeEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);
        _socket.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
        _socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,
                                    securityErrorHandler);
        try {
          _socket.close();
        } catch (error:IOError) {
        } finally {
          _socket = null;
        }
      }

      if (_url != null) {
        idx = connectionCollections[_url].indexOf(this);
        if (idx != -1) {
          connectionCollections[_url].splice(idx, 1);          
        }

        if (connectionCollections[_url].length == 0) {
          delete connectionCollections[_url];
        }

        _url = null;
      }

      _channels = null;
      _connecting = false;
      _handshaked = false;
    }

  }
}
