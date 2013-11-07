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
  import flash.errors.IOError;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;


  public class Channel extends EventDispatcher {

    public static var PAYLOAD_MAX_SIZE:Number = Frame.PAYLOAD_MAX_SIZE;

    private var _ptr:uint = Number.NaN;
    private var _path:String = null;

    private var _url:String = null;

    private var _mode:Number;

    private var _closing:Boolean = false;
    private var _resolved:Boolean = false;
    private var _connecting:Boolean = false;
    private var _connected:Boolean = false;
    private var _readable:Boolean = false;
    private var _writable:Boolean = false;
    private var _emitable:Boolean = false;

    private var _connection:Connection = null;

    private var _openData:ByteArray = null;
    private var _openCType:Number = Frame.PAYLOAD_UTF;

    private var _closeData:ByteArray = null;
    private var _closeOffset:uint = 0;
    private var _closeLength:uint = 0;
    private var _closeCType:Number = Frame.PAYLOAD_UTF;


    /**
     *  Initializes a new Channel instance
     */
    public function Channel() {
    }


    /**
     *  Return the connected state for this Channel instance.
     */
    public function get connected () : Boolean {
      return _connected;
    }


    /**
     *  Returns true if channel is connecting.
     *
     *  @return {Boolean} true if channel is connecting, else false.
     */
    public function get connecting () : Boolean {
      return _connecting;
    }


    /**
     *  Returns true if channel is closing.
     *
     *  @return {Boolean} true if channel is closing, else false.
     */
    public function get closing() : Boolean {
      return _closing;
    }


    /**
     *  Return true if channel is readable
     */
    public function get readable () : Boolean {
      return _connected && _readable;
    }


    /**
     *  Return true if channel is writable
     */
    public function get writable () : Boolean {
      return _connected && _writable;
    }


    /**
     *  Return true if channel emitable.
     */
    public function get emitable () : Boolean {
      return _connected && _emitable;
    }


    /**
     *  Returns channel mode
     */
    public function get mode () : Number {
      return _mode;
    }


    /**
     *  Returns the url for this instance.
     *
     *  @return {String} the specified hostname.
     */
    public function get url () : String {
      return _url;
    }


    /**
     *  @private
     */
    internal function get ptr () : uint {
      return _ptr;
    }


    /**
     *  @private
     */
    internal function set ptr (value:uint) : void {
      _ptr = value;
    }


    /**
     *  @private
     */
    internal function get resolved () : boolean {
      return _resolved;
    }


    /**
     *  @private
     */
    internal function set resolved (value:boolean) : void {
      _resolved = value;
    }


    /**
     *  @private
     */
    internal function get path () : String {
      return _path;
    }


    /**
     *  @private
     */
    internal function get openData () : ByteArray {
      return _openData;
    }


    /**
     *  @private
     */
    internal function get openCType () : Number {
      return _openCType;
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
    public function connect (url:String, mode:Number=ChannelMode.READ) : void {
      var urlobj:Object;
      var token:String;

      if (_connection) {
        throw new Error("Already connected");
      }

      if (mode < 0 || mode > ChannelMode.READWRITEEMIT) {
        throw new Error("Invalid mode");
      }

      if (url == null) {
        throw new Error("Expected `url`");
      }

      if (/^http:|^https:/.test(url) == false) {
        url = "http://" + url;
      }

      urlobj = URLParser.parse(url);

      if (urlobj.protocol !== "http" && urlobj.protocol !== "https") {
        throw new Error("Unsupported protocol, expected HTTP/HTTPS");
      }

      if (urlobj.protocol == "https" && Connection.hasTlsSupport() == false) {
        throw new Error("Protocol HTTPS is not supported on platform");
      }

      if (urlobj.paramStr) {
        _openData = new ByteArray()
        _openData.writeUTFBytes(urlobj.paramStr);        
        _openCType = Frame.PAYLOAD_UTF;
      }

      _mode = mode;

      try {
        _connection = Connection.getConnection(this, urlobj);
      } catch (err:Error) {
        _openData = null;
        _openCType = Frame.PAYLOAD_UTF;
        _connection = null;
        _mode = 0;
        throw err;
      }

      _path = urlobj.path;
      _url = _connection.url + _path;

      _readable = ((_mode & ChannelMode.READ) == ChannelMode.READ);
      _writable = ((_mode & ChannelMode.WRITE) == ChannelMode.WRITE);
      _emitable = ((_mode & ChannelMode.EMIT) == ChannelMode.EMIT);

      _connecting = true;
    }


    /**
     *  Writes a UTF-8 string to the channel. Similar to the writeUTF()
     *  method, but writeUTFBytes() does not prefix the string with a 16-bit
     *  length word.
     *
     *  @param data The string to write to the channel.
     */
    public function write(data:String, priority:uint=0) : void {
      var buffer:ByteArray;

      if (data == null || data.length == 0) {
        throw new Error('Expected data as String');
      }

      buffer = new ByteArray();
      buffer.writeUTFBytes(data);

      _write(Frame.PAYLOAD_UTF, priority, buffer);
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

      if (data == null || data.length == 0) {
        throw new Error('Expected data as non-empty ByteArray');
      }

      _write(Frame.PAYLOAD_BIN, priority, data, offset, length);
    }


    /**
     *  Emit's a signal to the channel.
     *
     *  <p>Note: Channel must be opened with the mode EMIT in order to use
     *     the emit method.</p>
     *
     *  @param value The string to write to the channel.
     */
    public function emit(data:String) : void {
      var buffer:ByteArray;

      if (data == null || data.length == 0) {
        throw new Error('Expected data as String');
      }

      buffer = new ByteArray();
      buffer.writeUTFBytes(data);

      _emit(Frame.PAYLOAD_UTF, buffer);
    }


    /**
     *  Emit's a signal to the channel.
     *
     *  <p>Note: Channel must be opened with the mode EMIT in order to use
     *     the emit method.</p>
     *
     *  @param data The string to write to the channel.
     */
    public function emitBytes(data:ByteArray,
                              offset:uint=0,
                              length:uint=0) : void {

      if (data == null || data.length == 0) {
        throw new Error('Expected data as String');
      }

      _emit(Frame.PAYLOAD_BIN, data, offset, length);
    }


    /**
     *  Closes the Channel instance.
     *
     *  @param message An optional message to send with the close signal.
     */
    public function close(message:String=null) : void {
      var data:ByteArray;

      if (message != null) {
        data = new ByteArray();
        data.writeUTFBytes(message);
      }

      _close(Frame.PAYLOAD_UTF, data);
    }


    /**
     *  Closes the Channel instance.
     *
     *  @param message An optional message to send with the close signal.
     */
    public function closeBytes(data:ByteArray,
                               offset:uint=0,
                               length:uint=0) : void {
      _close(Frame.PAYLOAD_BIN, data, offset, length);
    }


    /**
     *  @private
     */
    internal function openHandler (event:Event) : void {
      var frame:Frame;

      _connected = true;
      _connecting = false;

      _openData = null;
      _openCType = Frame.PAYLOAD_UTF;

      if (_closing) {
        frame = new Frame(_ptr,
                          _closeCType,
                          Frame.SIGNAL,
                          Frame.SIG_END,
                          _closeData,
                          _closeOffset,
                          _closeLength);

        _closeData = null;
        _closeOffset = 0;
        _closeLength = 0;
        _closeCType = Frame.PAYLOAD_UTF;
        flushFrame(frame);
        return;
      }

      dispatchEvent(event);
    }

    /**
     *  @private
     */
    internal function destroyHandler (event:Event) : void {
      _path = null;
      _ptr = Number.NaN;
      _url = null;
      _mode = 0;

      _closing = false;
      _connected = false;
      _connecting = false;
      _readable = false;
      _writable = false;
      _emitable = false;

      _openCType = Frame.PAYLOAD_UTF;
      _openData = null;

      _closeCType = Frame.PAYLOAD_UTF;
      _closeData = null;
      _closeOffset = 0;
      _closeLength = 0;

      dispatchEvent(event);
    }


    private function _write(ctype:uint,
                            priority:uint,
                            data:ByteArray,
                            offset:uint=0,
                            length:uint=0) : void {
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

      frame = new Frame(_ptr, ctype, Frame.DATA, priority, data, offset, length);
      flushFrame(frame);
    }


    private function _emit(ctype:uint,
                           data:ByteArray,
                           offset:uint=0,
                           length:uint=0) : void {
      var frame:Frame;

      if (connected == false || _connection == null) {
        throw new IOError("Channel is not connected.");
      }

      if (!_emitable) {
        throw new Error("You do not have permission to send signals");
      }

      frame = new Frame(_ptr,
                        ctype,
                        Frame.SIGNAL,
                        Frame.SIG_EMIT,
                        data,
                        offset,
                        length);

      flushFrame(frame);
    }


    private function _close(ctype:uint,
                            data:ByteArray,
                            offset:uint=0,
                            length:uint=0) : void {
      var frame:Frame;

      if (_connection == null || _closing) {
        return;
      }

      _closing = true;
      _readable = false;
      _writable = false;
      _emitable = false;

      if (_connecting == true) {
        // Open request is not responded to yet. Wait to send ENDSIG until
        // we get an OPENRESP.
        _closeCType = ctype;
        _closeData = data;
        _closeOffset = offset;
        _closeLength = length;
        return;
      }

      frame = new Frame(_ptr,
                        ctype,
                        Frame.SIGNAL,
                        Frame.SIG_END,
                        data,
                        offset,
                        length);

      flushFrame(frame);
    }


    private function flushFrame(frame:Frame) : void {
      _connection.writeFrame(frame);
    }

  }

}