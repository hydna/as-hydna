// HydnaStream.as

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
package com.hydna {
  
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  
  import com.hydna.HydnaAddr;
  import com.hydna.HydnaStreamEvent;
  import com.hydna.HydnaStreamMode;
  import com.hydna.HydnaPacket;

  public class HydnaStream extends EventDispatcher {
    
    private var _addr:HydnaAddr = null;
    private var _mode:String = null;
    private var _open:Boolean = false;
    private var _originalAddr:HydnaAddr = null;
    private var _socket:Socket = null;
    private var _token:String = null;
    
    /**
     * Initializes a new HydnaStream instance
     */
    public function HydnaStream(socket:Socket, 
                                  addr:HydnaAddr, 
                                  mode:String,
                                  token:String) {
      _socket = socket;
      _addr = addr;
      _originalAddr = addr;
      _mode = mode;
      _token = token;
    }
    
    /**
     *  Returns open status for this HydnaStream instance.
     *
     *  @return {Boolean} true if stream is open to the specified
     *                    HydnaAddr else false.
     */
    public function get isOpen() : Boolean {
      return _open;
    }

    /**
     *  Returns the HydnaAddr that this instance listen to.
     *
     *  @return {HydnaAddr} the specified HydnaAddr instance.
     */
    public function get addr() : HydnaAddr {
      return _addr;
    }

    /**
     *  Returns the orignal assigned HydnaAddr instance.
     *
     *  @return {HydnaAddr} the original assigned HydnaAddr instance.
     */
    public function get originalAddr() : HydnaAddr {
      return _originalAddr;
    }
    
    /**
     *  Returns the mode of the HydnaStram
     *
     *  @return {String} current mode
     */
    public function get mode() : String {
      return _mode;
    }
    
    public function write(data:ByteArray) : void {
      
      if (_open == false) {
        throw new Error("Stream is not open.");
      }

      if (_mode == HydnaStreamMode.READ) {
        throw new Error("Stream is not writable");
      }
      
      _socket.writeShort(data.length + HydnaPacket.HEADER_LENGTH);
      _socket.writeByte(HydnaPacket.EMIT);
      _socket.writeByte(0);
      _socket.writeBytes(_addr.bytes, 0, _addr.bytes.length);
      _socket.writeBytes(data, 0, data.length);
      _socket.flush();
    }
    
    public function close() : void {
      internalClose();
    }
    
    public function writeString(value:String) : void {
      var data:ByteArray = new ByteArray();
      data.writeUTF(value);
      write(data);
    }
    
    /**
     *  Internal method. Sends an open request from stream address.
     * 
     */
    internal function open() : void {
      var addr:HydnaAddr = this._addr;
      var token:String = this._token;
      var packetLength:Number = 13;
      var tokenBuffer:ByteArray = null;
      var mode:Number = 0;
      
      switch (this._mode) {
        case HydnaStreamMode.READ: 
          mode = 1;
          break;
          
        case HydnaStreamMode.WRITE: 
          mode = 2;
          break;
          
        case HydnaStreamMode.READWRITE: 
          mode = 3;
          break;
      }
      
      function postOpen() : void {

        if (token !== null) {
          tokenBuffer = new ByteArray();
          tokenBuffer.writeUTF(token);
          packetLength += tokenBuffer.length;
        }

        _socket.writeShort(packetLength);
        _socket.writeByte(HydnaPacket.OPEN);
        _socket.writeByte(0);
        _socket.writeBytes(addr.bytes, 0, addr.bytes.length);
        _socket.writeByte(mode);

        if (tokenBuffer) {
          _socket.writeBytes(tokenBuffer, 0, tokenBuffer.length);
        }
        
        _socket.flush();
      }
      
      if (_socket.connected) {
        postOpen();
      } else {
        _socket.addEventListener(Event.CONNECT, postOpen);
      }
    }
    
    internal function internalClose(error:Number=0) : void {
      if (_open) {
        var event:HydnaStreamEvent = new HydnaStreamEvent(HydnaStreamEvent.CLOSE);
        _open = false;
        dispatchEvent(event);
      }
    }
    
    internal function processData(buffer:ByteArray, length:Number) : void {
      var tempBuffer:ByteArray = new ByteArray();
      var event:HydnaStreamEvent;
      buffer.readBytes(tempBuffer, 0, length);
      event = new HydnaStreamEvent(HydnaStreamEvent.DATA, 0, tempBuffer);
      dispatchEvent(event);
    }

    internal function setOpenState(code:Number, responseAddr:String) : void {
      var event:HydnaStreamEvent = null;
      
      if (code == 0) {
        _open = true;
        _addr = HydnaAddr.fromChars(responseAddr);
        event = new HydnaStreamEvent(HydnaStreamEvent.OPEN);
      } else {
        event = new HydnaStreamEvent(HydnaStreamEvent.ERROR, code);
      }
      
      dispatchEvent(event);
    }
    
  }
  
}