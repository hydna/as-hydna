// Channel.as

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
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.errors.IOError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;

  import hydna.net.ChannelErrorEvent;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelEmitEvent;
  import hydna.net.Channel;
  import hydna.net.ChannelMode;

  public class Channel extends EventDispatcher {

    private static const DEFAULT_PORT:Number = 7010;
    private static const URI_RE:RegExp = /(?:hydna:){0,1}([\w\-\.]+)(?::(\d+)){0,1}(?:\/(\d+|x[a-fA-F0-9]+){0,1}){0,1}(?:\?(.+)){0,1}/;

    private var _ch:uint = 0;
    private var _uri:String = null;
    private var _token:String = null;
    private var _closing:Boolean = false;

    private var _socket:Connection = null;
    private var _connected:Boolean = false;
    private var _pendingClose:Packet = null;

    private var _readable:Boolean = false;
    private var _writable:Boolean = false;
    private var _emitable:Boolean = false;

    private var _mode:Number;

    private var _openRequest:OpenRequest;


    /**
     *  Initializes a new Channel instance
     */
    public function Channel() {
    }

    /**
     *  Return the connected state for this Channel instance.
     */
    public function get connected() : Boolean {
      return _connected;
    }

    /**
     *  Return true if stream is readable
     */
    public function get readable() : Boolean {
      return _connected && _readable;
    }

    /**
     *  Return true if stream is writable
     */
    public function get writable() : Boolean {
      return _connected && _writable;
    }

    /**
     *  Return true if stream emitable.
     */
    public function get emitable() : Boolean {
      return _connected && _emitable;
    }

    /**
     *  Returns the channel that this instance listen to.
     *
     *  @return {Number} the specified channel number.
     */
    public function get channel() : Number {
      return _ch;
    }

    /**
     *  Returns the url for this instance.
     *
     *  @return {String} the specified hostname.
     */
    public function get uri() : String {

      if (!_uri) {
        _uri = _socket.uri + "/" + _ch + (_token ? "?" + _token : "");
      }

      return _uri;
    }

    /**
     *  Connects the stream to the specified uri. If the connection fails
     *  immediately, either an event is dispatched or an exception is thrown:
     *  an error event is dispatched if a host was specified, and an exception
     *  is thrown if no host was specified. Otherwise, the status of the
     *  connection is reported by an event. If the socket is already
     *  connected, the existing connection is closed first.
     *
     *  By default, the value you pass for host must be in the same domain
     *  and the value you pass for port must be 1024 or higher. For example,
     *  a SWF file at adobe.com can connect only to a server daemon running
     *  at adobe.com. If you want to connect to a socket on a different host
     *  than the one from which the connecting SWF file was served, or if you
     *  want to connect to a port lower than 1024 on any host, you must
     *  obtain an xmlsocket: policy file from the host to which you are
     *  connecting. Howver, these restrictions do not exist for AIR content
     *  in the application security sandbox. For more information, see the
     *  "Flash Player Security" chapter in Programming ActionScript 3.0.
     */
    public function connect( uri:String
                           , mode:Number=ChannelMode.READ
                           , token:ByteArray=null
                           , tokenOffset:uint=0
                           , tokenLength:uint=0) : void {
      var m:Array;
      var packet:Packet;
      var request:OpenRequest;
      var tokenb:ByteArray = null;
      var tokeno:uint = 0;
      var tokenl:uint = 0;
      var ch:Number;
      var host:String;
      var port:Number;

      if (_socket) {
        throw new Error("Already connected");
      }

      if (uri == null) {
        throw new Error("Expected `uri`");
      }

      m = URI_RE.exec(uri);

      host = m[1];
      port = m[2] || DEFAULT_PORT;

      if (!host) {
        throw new Error("Expected hostname");
      }

      if (host.length > 256) {
        throw new Error("Hostname must not exceed 256 characters");
      }

      if (m[3]) {
        if (m[3].charAt(0) == "x") {
          ch = parseInt("0" + m[3]);
        } else {
          ch = parseInt(m[3]);
        }
      } else {
        ch = 1;
      }

      if (ch == 0 || ch > 0xFFFFFFFF) {
        throw new Error("Expected channel between x1 and xFFFFFFFF");
      }

      if (token != null) {
        tokenb = token;
        tokeno = tokenOffset;
        tokenl = tokenLength;
      } else if (m[4]) {
        tokenb = new ByteArray();
        tokenb.writeMultiByte(decodeURIComponent(m[4]), "us-ascii");
        tokenb.position = 0;
        tokeno = 0;
        tokenl = tokenb.length;
      }

      if (tokenb != null) {
        _token = encodeURIComponent(
                  tokenb.readMultiByte(tokenb.length, "us-ascii"));
        tokenb.position = 0;
      }

      if (mode < 0 || mode > ChannelMode.READWRITEEMIT) {
        throw new Error("Invalid stream mode");
      }

      _mode = mode;

      _readable = ((_mode & ChannelMode.READ) == ChannelMode.READ);
      _writable = ((_mode & ChannelMode.WRITE) == ChannelMode.WRITE);
      _emitable = ((_mode & ChannelMode.EMIT) == ChannelMode.EMIT);

      _socket = Connection.getSocket(host, port);

      // Ref count
      _socket.allocChannel();

      packet = new Packet(ch, Packet.OPEN, mode, tokenb, tokeno, tokenl);

      request = new OpenRequest(this, ch, packet);

      if (_socket.requestOpen(request) == false) {
        throw new Error("Channel already open");
      }

      _openRequest = request;
    }

    /**
     *  Writes a sequence of bytes from the specified byte array. The write
     *  operation starts at the <code>position</code> specified by offset.
     *
     *  <p>If you omit the length parameter the default length of 0 causes
     *  the method to write the entire buffer starting at offset.</p>
     *
     *  <p>If you also omit the <code>offset</code> parameter, the entire
     *  buffer is written.</p>
     *
     *  <p>If offset or length is out of range, they are adjusted to match
     *  the beginning and end of the bytes array.</p>
     */
    public function writeBytes( data:ByteArray
                              , offset:uint=0
                              , length:uint=0
                              , priority:uint=1) : void {
      var packet:Packet;

      if (connected == false || _socket == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_writable) {
        throw new Error("Channel is not writable");
      }

      if (priority < 1 || priority > 5) {
        throw new RangeError("Priority must be between 1 - 5");
      }

      packet = new Packet( _ch, Packet.DATA, priority
                         , data, offset, length);

      _socket.writeBytes(packet);
      _socket.flush();
    }

    /**
     *  Writes the following data to the socket: a 16-bit unsigned integer,
     *  which indicates the length of the specified UTF-8 string in bytes,
     *  followed by the string itself.
     *
     *  @param {String} value The string to write to the stream.
     */
    public function writeUTF(value:String) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTF(value);
      writeBytes(data);
    }

    /**
     *  Writes a UTF-8 string to the stream. Similar to the writeUTF()
     *  method, but writeUTFBytes() does not prefix the string with a 16-bit
     *  length word.
     *
     *  @param value The string to write to the stream.
     */
    public function writeUTFBytes(value:String) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTFBytes(value);
      writeBytes(data);
    }

    /**
     *  Emit's a signal to the stream.
     *
     *  <p>Note: Channel must be opened with the mode EMIT in order to use
     *     the emit method.</p>
     *
     *  @param value The string to write to the stream.
     */
    public function emit( data:ByteArray
                        , offset:uint=0
                        , length:uint=0) : void {
      var packet:Packet;

      if (connected == false || _socket == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_emitable) {
        throw new Error("You do not have permission to send signals");
      }

      packet = new Packet( _ch, Packet.SIGNAL, Packet.SIG_EMIT
                         , data, offset, length);

      _socket.writeBytes(packet);
      _socket.flush();
    }

    /**
     *  Emit's an UTF-8 signal to the stream.
     *
     *  @param value The string to emit to the stream.
     *  @param type An optional type for the signal.
     */
    public function emitUTFBytes(value:String, type:Number=0) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTFBytes(value);
      emit(data);
    }

    /**
     *  Closes the Channel instance.
     *
     *  @param message An optional message to send with the close signal.
     */
    public function close(message:String=null) : void {
      var packet:Packet;
      var payload:ByteArray;

      if (_socket == null || _closing) {
        return;
      }

      _closing = true;
      _readable = false;
      _writable = false;
      _emitable = false;

      if (message != null) {
        payload = new ByteArray();
        payload.writeUTFBytes(message);
      }

      if (_openRequest != null && _socket.cancelOpen(_openRequest)) {
        // Open request hasn't been posted yet, which means that it's
        // safe to destroy stream immediately.

        _openRequest = null;
        destroy();
        return;
      }

      packet = new Packet(_ch, Packet.SIGNAL, Packet.SIG_END, payload);

      if (_openRequest != null) {
        // Open request is not responded to yet. Wait to send ENDSIG until
        // we get an OPENRESP.

        _pendingClose = packet;
      } else {
        try {
          _socket.writeBytes(packet);
          _socket.flush();
        } catch (error:IOError) {
          destroy(ChannelErrorEvent.fromError(error));
        }
      }
    }

    internal function isClosing() : Boolean {
      return _closing;
    }

    // Internal callback for open success
    internal function openSuccess(respch:uint) : void {
      var origch:uint = _ch;
      var packet:Packet;

      _openRequest = null;
      _ch = respch;
      _connected = true;

      if (_pendingClose) {

        packet = _pendingClose;
        _pendingClose = null;

        if (origch != respch) {
          // channel is changed. We need to change the channel of the
          //packet before sending to server.

          packet.channel = respch;
        }

        try {
          _socket.writeBytes(packet);
          _socket.flush();
        } catch (error:IOError) {
          // Something wen't terrible wrong. Queue packet and wait
          // for a reconnect.

          destroy(ChannelErrorEvent.fromError(error));
        }
      } else {
        dispatchEvent(new Event(Event.CONNECT));
      }
    }

    // Internally destroy socket.
    internal function destroy(event:Event=null) : void {
      var socket:Connection = _socket;
      var connected:Boolean = _connected;
      var ch:uint = _ch;

      _ch = 0;
      _connected = false;
      _writable = false;
      _readable = false;
      _pendingClose = null;
      _closing = false;
      _pendingClose = null;
      _socket = null;

      if (socket) {
        socket.deallocChannel(connected ? ch : 0);
      }

      if (event != null) {
        dispatchEvent(event);
      }
    }

  }

}