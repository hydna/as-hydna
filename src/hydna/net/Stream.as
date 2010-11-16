// Stream.as

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
  
  import hydna.net.Addr;
  import hydna.net.StreamErrorEvent;
  import hydna.net.StreamDataEvent;
  import hydna.net.StreamSignalEvent;
  import hydna.net.Stream;
  import hydna.net.StreamMode;

  public class Stream extends EventDispatcher {
    
    private var _addr:Addr = null;

    private var _socket:HydnaSocket = null;
    private var _connected:Boolean = false;
    private var _pendingClose:Boolean = false;
    
    private var _readable:Boolean = false;
    private var _writable:Boolean = false;
    private var _signalSupport:Boolean = false;

    private var _mode:Number;
    
    private var _openRequest:OpenRequest;
        
    
    /**
     *  Initializes a new Stream instance
     */
    public function Stream() {
    }
    
    /**
     *  Return the connected state for this Stream instance.
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
     *  Return true if stream has signal support.
     */
    public function get signalSupport() : Boolean {
      return !_pendingClose && _connected && _writable;
    }
    
    /**
     *  Returns the HydnaAddr that this instance listen to.
     *
     *  @return {HydnaAddr} the specified HydnaAddr instance.
     */
    public function get addr() : Addr {
      return _addr;
    }
    
    /**
     *  Connects the stream to the specified addr. If the connection fails 
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
    public function connect( addrExpr:String
                           , mode:Number=StreamMode.READ
                           , token:ByteArray=null
                           , tokenOffset:uint=0
                           , tokenLength:uint=0) : void {
      var addr:Addr;
      var message:Message;
      var request:OpenRequest;
      
      if (_socket) {
        throw new Error("Already connected");
      }
      
      _addr = Addr.fromExpr(addrExpr);
                             
      if (mode == 0x04 ||
          mode < StreamMode.READ || 
          mode > StreamMode.READWRITE_SIG) {
        throw new Error("Invalid stream mode");
      }
      
      _mode = mode;
      
      _readable = ((_mode & StreamMode.READ) == StreamMode.READ);
      _writable = ((_mode & StreamMode.WRITE) == StreamMode.WRITE);
      _signalSupport = ((_mode & 0x04) == 0x04);
      
      _socket = HydnaSocket.getSocket(_addr);
      
      // Ref count
      _socket.allocStream();
      
      message = new Message(_addr, Message.OPEN, mode,
                            token, tokenOffset, tokenLength);
      
      request = new OpenRequest(this, _addr, message);
      
      if (_socket.requestOpen(request) == false) {
        throw new Error("Stream already open");
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
                              , priority:uint=0) : void {
      var message:Message;

      if (connected == false || _socket == null) {
        throw new IOError("Stream is not connected.");
      }

      if (_mode == StreamMode.READ) {
        throw new Error("Stream is not writable");
      }
      
      if (priority > 3) {
        throw new RangeError("Priority must be between 0 - 3");
      }
      
      message = new Message(_addr, Message.EMIT, priority,
                            data, offset, length);


      _socket.writeBytes(message);
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
     *  Sends a signal to the stream.
     *
     *  <p>Note: Signal write access is permitted in order to send via
     *     network.</p>
     *
     *  @param value The string to write to the stream.
     */
    public function sendSignal( data:ByteArray
                              , offset:uint=0
                              , length:uint=0
                              , type:uint=0) : void {
      var message:Message;
                                
      if (connected == false || _socket == null) {
        throw new IOError("Stream is not connected.");
      }

      if ((_mode & 0x4) == 0x4) {
        throw new Error("You do not have permission to send signals");
      }

      message = new Message(_addr, Message.SIGNAL, type,
                            data, offset, length);

      _socket.writeBytes(message);
      _socket.flush();
    }

    /**
     *  Sends a UTF-8 signal to the stream. 
     *
     *  @param value The string to write to the stream.
     *  @param type An optional type for the signal. 
     */
    public function sendUTFSignal(value:String, type:Number=0) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTFBytes(value);
      sendSignal(data);
    }
    
    /**
     *  Closes the Stream instance.
     */
    public function close() : void {
      if (_socket == null || _pendingClose == true) return;
      
      if (_openRequest != null) {
        if (_socket.cancelOpen(_openRequest)) {
          _openRequest = null;
          destroy();
        } else {
          _pendingClose = true;
        }
      } else {
        internalClose();
      }
    }
    
    // Internal callback for open success
    internal function openSuccess(respaddr:Addr) : void {
      _addr = respaddr;
      _connected = true;
      
      if (_pendingClose) {
        internalClose();
      } else {
        dispatchEvent(new Event(Event.CONNECT));
      }
    }

    // Internally destroy socket.
    internal function destroy(event:Event=null) : void {
      _connected = false;
      _pendingClose = false;
      _writable = false;
      _readable = false;
      
      if (_socket) {
        _socket.deallocStream(_connected ? _addr : null);
      }

      _addr = null;
      _socket = null;
      
      if (event != null) {
        dispatchEvent(event);
      } 
    }
    
    // Internally close stream
    private function internalClose() : void {
      var event:Event = null;
      var message:Message;
      
      message = new Message(_addr, Message.CLOSE);

      if (_socket && _socket.handshaked) {
        try {
          _socket.writeBytes(message);
          _socket.flush();
        } catch (error:IOErrorEvent) {
          // Something wen't terrible wrong. Queue message and wait 
          // for a reconnect.
          event = error;
        }
      }

      destroy(event);
    }
    
  }
  
}