// HydnaDataStream.as

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
  import com.hydna.HydnaStream;
  import com.hydna.HydnaStreamEvent;
  import com.hydna.HydnaDataStreamMode;
  import com.hydna.HydnaStreamType;
  import com.hydna.HydnaPacket;

  public class HydnaDataStream extends HydnaStream {
    
    private var _mode:String = null;
    private var _token:String = null;
    
    /**
     * Initializes a new HydnaStream instance
     */
    public function HydnaDataStream(socket:Socket, 
                                  addr:HydnaAddr, 
                                  mode:String,
                                  token:String) {
      super(HydnaStreamType.DATA, socket, addr);
      _mode = mode;
      _token = token;
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
      
      if (connected == false) {
        throw new Error("Stream is not connected.");
      }

      if (_mode == HydnaDataStreamMode.READ) {
        throw new Error("Stream is not writable");
      }
      
      socket.writeShort(data.length + HydnaPacket.HEADER_LENGTH);
      socket.writeByte(HydnaPacket.EMIT);
      socket.writeByte(0);
      socket.writeBytes(addr.bytes, 0, addr.bytes.length);
      socket.writeBytes(data, 0, data.length);
      socket.flush();
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
      write(data);
    }
    
    /**
     *  Internal method. Sends an open request from stream address.
     * 
     */
    internal function open() : void {
      var token:String = this._token;
      var packetLength:Number = 13;
      var tokenBuffer:ByteArray = null;
      var mode:Number = 0;
      
      switch (this._mode) {
        case HydnaDataStreamMode.READ: 
          mode = 1;
          break;
          
        case HydnaDataStreamMode.WRITE: 
          mode = 2;
          break;
          
        case HydnaDataStreamMode.READWRITE: 
          mode = 3;
          break;
      }
      
      function postOpen() : void {

        if (token !== null) {
          tokenBuffer = new ByteArray();
          tokenBuffer.writeUTF(token);
          packetLength += tokenBuffer.length;
        }

        socket.writeShort(packetLength);
        socket.writeByte(HydnaPacket.OPEN);
        socket.writeByte(0);
        socket.writeBytes(addr.bytes, 0, addr.bytes.length);
        socket.writeByte(mode);

        if (tokenBuffer) {
          socket.writeBytes(tokenBuffer, 0, tokenBuffer.length);
        }
        
        socket.flush();
      }
      
      if (socket.connected) {
        postOpen();
      } else {
        socket.addEventListener(Event.CONNECT, postOpen);
      }
    }
    
    override public function close() : Boolean {
      if (super.close()) {
        if (socket.connected) {
          socket.writeShort(HydnaPacket.HEADER_LENGTH);
          socket.writeByte(HydnaPacket.CLOSE);
          socket.writeByte(0);
          socket.writeBytes(addr.bytes, 0, addr.bytes.length);
          socket.flush();
        } else {
          internalClose(0);
        }
        return true;
      }
      
      return false;
    }
    
    override internal function internalClose(error:Number=0) : void {
      setConnected(false);
      var event:Event = new Event(Event.CLOSE);
      dispatchEvent(event);
    }
    
  }
  
}