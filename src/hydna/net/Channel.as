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

    private var _id:uint = 0;
    private var _uri:String = null;
    private var _token:String = null;
    private var _closing:Boolean = false;

    private var connection:Connection = null;
    private var _connected:Boolean = false;
    private var _pendingClose:Frame = null;

    private var _readable:Boolean = false;
    private var _writable:Boolean = false;
    private var _emitable:Boolean = false;

    private var _mode:Number;

    private var _openRequest:OpenRequest;

    /**
     *  Returns the ID of this Channel instance.
     *
     *  @return {Number} the specified ID number.
     */
    public function get id() : uint {
      return _id;
    }

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
     *  Return true if channel is readable
     */
    public function get readable() : Boolean {
      return _connected && _readable;
    }

    /**
     *  Return true if channel is writable
     */
    public function get writable() : Boolean {
      return _connected && _writable;
    }

    /**
     *  Return true if channel emitable.
     */
    public function get emitable() : Boolean {
      return _connected && _emitable;
    }

    /**
     *  Returns the url for this instance.
     *
     *  @return {String} the specified hostname.
     */
    public function get uri() : String {

      if (!_uri) {
        _uri = connection.uri + "/" + _id + (_token ? "?" + _token : "");
      }

      return _uri;
    }

    /**
     *  Connects the channel to the specified uri. If the connection fails
     *  immediately, either an event is dispatched or an exception is thrown:
     *  an error event is dispatched if a host was specified, and an exception
     *  is thrown if no host was specified. Otherwise, the status of the
     *  connection is reported by an event. If the connection is already
     *  connected, the existing connection is closed first.
     *
     *  By default, the value you pass for host must be in the same domain
     *  and the value you pass for port must be 1024 or higher. For example,
     *  a SWF file at adobe.com can connect only to a server daemon running
     *  at adobe.com. If you want to connect to a connection on a different host
     *  than the one from which the connecting SWF file was served, or if you
     *  want to connect to a port lower than 1024 on any host, you must
     *  obtain an xmlconnection: policy file from the host to which you are
     *  connecting. Howver, these restrictions do not exist for AIR content
     *  in the application security sandbox. For more information, see the
     *  "Flash Player Security" chapter in Programming ActionScript 3.0.
     */
    public function connect(uri:String,
                            mode:Number=ChannelMode.READ,
                            token:ByteArray=null,
                            tokenOffset:uint=0,
                            tokenLength:uint=0) : void {
      var m:Array;
      var frame:Frame;
      var request:OpenRequest;
      var tokenb:ByteArray = null;
      var tokeno:uint = 0;
      var tokenl:uint = 0;
      var id:Number;
      var host:String;
      var port:Number;

      if (connection) {
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
          id = parseInt("0" + m[3]);
        } else {
          id = parseInt(m[3]);
        }
      } else {
        id = 1;
      }

      if (id == 0 || id > 0xFFFFFFFF) {
        throw new Error("Out of range, expected channel id" +
                        "between 0x1 and 0xFFFFFFFF");
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
        throw new Error("Invalid channel mode");
      }

      _mode = mode;

      _readable = ((_mode & ChannelMode.READ) == ChannelMode.READ);
      _writable = ((_mode & ChannelMode.WRITE) == ChannelMode.WRITE);
      _emitable = ((_mode & ChannelMode.EMIT) == ChannelMode.EMIT);

      connection = Connection.getSocket(host, port);

      // Ref count
      connection.allocChannel();

      frame = new Frame(id, Frame.OPEN, mode, tokenb, tokeno, tokenl);

      request = new OpenRequest(this, id, frame);

      if (connection.requestOpen(request) == false) {
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
    public function writeBytes(data:ByteArray,
                               offset:uint=0,
                               length:uint=0,
                               priority:uint=1) : void {
      var frame:Frame;

      if (connected == false || connection == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_writable) {
        throw new Error("Channel is not writable");
      }

      if (priority < 1 || priority > 5) {
        throw new RangeError("Priority must be between 1 - 5");
      }

      frame = new Frame(_id, Frame.DATA, priority, data, offset, length);

      connection.writeBytes(frame);
      connection.flush();
    }

    /**
     *  Writes the following data to the connection: a 16-bit unsigned integer,
     *  which indicates the length of the specified UTF-8 string in bytes,
     *  followed by the string itself.
     *
     *  @param {String} value The string to write to the channel.
     */
    public function writeUTF(value:String) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTF(value);
      writeBytes(data);
    }

    /**
     *  Writes a UTF-8 string to the channel. Similar to the writeUTF()
     *  method, but writeUTFBytes() does not prefix the string with a 16-bit
     *  length word.
     *
     *  @param value The string to write to the channel.
     */
    public function writeUTFBytes(value:String) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTFBytes(value);
      writeBytes(data);
    }

    /**
     *  Emit's a signal to the channel.
     *
     *  <p>Note: Channel must be opened with the mode EMIT in order to use
     *     the emit method.</p>
     *
     *  @param value The string to write to the channel.
     */
    public function emit(data:ByteArray,
                         offset:uint=0,
                         length:uint=0) : void {
      var frame:Frame;

      if (connected == false || connection == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_emitable) {
        throw new Error("You do not have permission to send signals");
      }

      frame = new Frame(_id, Frame.SIGNAL, Frame.SIG_EMIT, data, offset, length);

      connection.writeBytes(frame);
      connection.flush();
    }

    /**
     *  Emit's an UTF-8 signal to the channel.
     *
     *  @param value The string to emit to the channel.
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
      var frame:Frame;
      var payload:ByteArray;

      if (connection == null || _closing) {
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

      if (_openRequest != null && connection.cancelOpen(_openRequest)) {
        // Open request hasn't been posted yet, which means that it's
        // safe to destroy channel immediately.

        _openRequest = null;
        destroy();
        return;
      }

      frame = new Frame(_id, Frame.SIGNAL, Frame.SIG_END, payload);

      if (_openRequest != null) {
        // Open request is not responded to yet. Wait to send ENDSIG until
        // we get an OPENRESP.

        _pendingClose = frame;
      } else {
        try {
          connection.writeBytes(frame);
          connection.flush();
        } catch (error:IOError) {
          destroy(ChannelErrorEvent.fromError(error));
        }
      }
    }

    internal function isClosing() : Boolean {
      return _closing;
    }

    // Internal callback for open success
    internal function openSuccess(respid:uint) : void {
      var origid:uint = _id;
      var frame:Frame;

      _openRequest = null;
      _id = respid;
      _connected = true;

      if (_pendingClose) {

        frame = _pendingClose;
        _pendingClose = null;

        if (origid != respid) {
          // channel is changed. We need to change the channel of the
          // frame before sending to server.

          frame.id = respid;
        }

        try {
          connection.writeBytes(frame);
          connection.flush();
        } catch (error:IOError) {
          // Something wen't terrible wrong. Queue frame and wait
          // for a reconnect.

          destroy(ChannelErrorEvent.fromError(error));
        }
      } else {
        dispatchEvent(new Event(Event.CONNECT));
      }
    }

    // Internally destroy connection.
    internal function destroy(event:Event=null) : void {
      var connection:Connection = connection;
      var connected:Boolean = _connected;
      var id:uint = _id;

      _id = 0;
      _connected = false;
      _writable = false;
      _readable = false;
      _pendingClose = null;
      _closing = false;
      _pendingClose = null;
      connection = null;

      if (connection) {
        connection.deallocChannel(connected ? id : 0);
      }

      if (event != null) {
        dispatchEvent(event);
      }
    }

  }

}