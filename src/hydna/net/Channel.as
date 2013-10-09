// Channel.as

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
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.errors.IOError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;

  import hydna.net.ChannelOpenEvent;
  import hydna.net.ChannelErrorEvent;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelSignalEvent;
  import hydna.net.Channel;
  import hydna.net.ChannelMode;
  import hydna.net.URLParser;

  public class Channel extends EventDispatcher {

    public static var PAYLOAD_MAX_SIZE:Number = Frame.PAYLOAD_MAX_SIZE;

    private var _id:uint = 0;
    private var _url:String = null;
    private var _token:String = null;
    private var _closing:Boolean = false;

    private var _connection:Connection = null;
    private var _connected:Boolean = false;
    private var _pendingClose:Frame = null;

    private var _readable:Boolean = false;
    private var _writable:Boolean = false;
    private var _emitable:Boolean = false;

    private var _mode:Number;

    private var _openRequest:OpenRequest;
    private var _pendingOpenRequest:OpenRequest;


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
    public function get url() : String {

      if (!_url) {
        _url = _connection.url + "/" + _id + (_token ? "?" + _token : "");
      }

      return _url;
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
    public function connect(url:String, mode:Number=ChannelMode.READ) : void {
      var connurl:String;
      var urlobj:Object;
      var frame:Frame;
      var request:OpenRequest;
      var token:ByteArray = null;
      var id:Number;

      if (_connection) {
        throw new Error("Already connected");
      }

      if (url == null) {
        throw new Error("Expected `url`");
      }

      if (/^http:|^https:/.test(url) == false) {
        url = "http://" + url;
      }

      urlobj = URLParser.parse(url);

      if (urlobj.protocol == "https") {
        throw new Error("Protocol HTTPS is currently not supported");
      }

      if (urlobj.protocol !== "http") {
        throw new Error("Unsupported protocol, expected HTTP/HTTPS");
      }

      if (!urlobj.host) {
        throw new Error("Expected hostname");
      }

      if (urlobj.host.length > 256) {
        throw new Error("Hostname must not exceed 256 characters");
      }

      if (urlobj.path) {
        id = parseInt((urlobj.path.charAt(0) == "x" ? "0" : "") + urlobj.path);
      } else {
        id = 1;
      }

      if (id < 1 || id > 0xFFFFFFFF) {
        throw new Error("Out of range, expected channel id" +
                        "between 0x1 and 0xFFFFFFFF");
      }

      if (urlobj.paramStr) {
        token = new ByteArray();
        token.writeUTFBytes(decodeURIComponent(urlobj.paramStr));
      }

      if (mode < 0 || mode > ChannelMode.READWRITEEMIT) {
        throw new Error("Invalid mode");
      }

      _mode = mode;

      _readable = ((_mode & ChannelMode.READ) == ChannelMode.READ);
      _writable = ((_mode & ChannelMode.WRITE) == ChannelMode.WRITE);
      _emitable = ((_mode & ChannelMode.EMIT) == ChannelMode.EMIT);

      connurl = urlobj.protocol + "://" + urlobj.host;

      if (urlobj.port) {
        connurl += ":" + urlobj.port;
      }

      if (urlobj.auth) {
        connurl += "/" + urlobj.auth;
      }

      _connection = Connection.getConnection(connurl);

      // Ref count
      _connection.allocChannel();

      frame = new Frame(id, Frame.OPEN, mode, token);

      request = new OpenRequest(this, id, frame);

      if (_connection.requestOpen(request) == false) {
        throw new Error("Channel is already open");
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
                               priority:uint=0) : void {
      var frame:Frame;

      if (connected == false || _connection == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_writable) {
        throw new Error("Channel is not writable");
      }

      if (priority < 0 || priority > 7) {
        throw new RangeError("Priority must be between 0 - 7");
      }

      frame = new Frame(_id, Frame.DATA, priority, data, offset, length);

      _connection.writeBytes(frame);
      _connection.flush();
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
    public function emit(message:String=null) : void {
      var frame:Frame;
      var data:ByteArray;

      if (connected == false || _connection == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_emitable) {
        throw new Error("You do not have permission to send signals");
      }

      if (message !== null) {
        data = new ByteArray();
        data.writeUTFBytes(message);
      }

      frame = new Frame(_id, Frame.SIGNAL, Frame.SIG_EMIT, data);

      _connection.writeBytes(frame);
      _connection.flush();
    }


    /**
     *  Closes the Channel instance.
     *
     *  @param message An optional message to send with the close signal.
     */
    public function close(message:String=null) : void {
      var frame:Frame;
      var data:ByteArray;

      if (_connection == null || _closing) {
        return;
      }

      _closing = true;
      _readable = false;
      _writable = false;
      _emitable = false;

      if (message != null) {
        data = new ByteArray();
        data.writeUTFBytes(message);
      }

      if (_openRequest != null && _connection.cancelOpen(_openRequest)) {
        // Open request hasn't been posted yet, which means that it's
        // safe to destroy channel immediately.

        _openRequest = null;
        destroy();
        return;
      }

      frame = new Frame(_id, Frame.SIGNAL, Frame.SIG_END, data);

      if (_openRequest != null) {
        // Open request is not responded to yet. Wait to send ENDSIG until
        // we get an OPENRESP.

        _pendingClose = frame;
      } else {
        try {
          _connection.writeBytes(frame);
          _connection.flush();
        } catch (error:IOError) {
          destroy(ChannelErrorEvent.fromError(error));
        }
      }
    }

    internal function isClosing() : Boolean {
      return _closing;
    }

    // Internal callback for open success
    internal function openSuccess(id:uint, message:String=null) : void {
      var frame:Frame;

      _openRequest = null;
      _id = id;
      _connected = true;

      if (_pendingClose) {

        frame = _pendingClose;
        _pendingClose = null;

        // channel is changed. We need to set the channel of the
        // frame before sending to server.
        frame.id = id;

        try {
          _connection.writeBytes(frame);
          _connection.flush();
        } catch (error:IOError) {
          // Something wen't terrible wrong. Queue frame and wait
          // for a reconnect.

          destroy(ChannelErrorEvent.fromError(error));
        }
      } else {
        dispatchEvent(new ChannelOpenEvent(message));
      }
    }

    internal function setPendingOpenRequest(request:OpenRequest) : void {
      
      if (_closing) {
        // Do not allow pending request if we are not closing.
        return false;
      }

      if (_pendingOpenRequest != null) {
        return _pendingOpenRequest.channel.setPendingOpenRequest(request);
      }

      _pendingOpenRequest = request;

      return true;
    }

    // Internally destroy connection.
    internal function destroy(event:Event=null) : void {
      var connection:Connection = _connection;
      var connected:Boolean = _connected;
      var request:OpenRequest;
      var id:uint = _id;

      _id = 0;
      _connected = false;
      _writable = false;
      _readable = false;
      _pendingClose = null;
      _closing = false;

      request = _pendingOpenRequest;
      _pendingOpenRequest = null;

      if (_connection) {

        if (request) {
          _connection.allocOpenRequest(request);
          _connection.flushPendingOpenRequest(request);
        }

        _connection.deallocChannel(connected ? id : 0);

        _connection = null;
      } else {

        if (request) {
          request.channel.destroy(event);
        }
      }

      if (event != null) {
        dispatchEvent(event);
      }
    }

  }

}