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
  import flash.events.IOErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  
  import com.hydna.HydnaAddr;
  import com.hydna.HydnaStream;
  import com.hydna.HydnaDataStreamMode;
  import com.hydna.HydnaStreamType;
  import com.hydna.HydnaPacket;

  public class HydnaDataStream extends HydnaStream {
    
    public static const MESSAGE_QUEUE_MAX:Number = 10000;
    
    private var _mode:String = null;
    private var _token:String = null;
    
    private var _messageQueue:Array;
    private var _messageQueueMax:Number;
    
    /**
     * Initializes a new HydnaStream instance
     */
    public function HydnaDataStream(addr:HydnaAddr, 
                                    mode:String,
                                    token:String) {
      super(HydnaStreamType.DATA, addr);
      _mode = mode;
      _token = token;
      _messageQueue = new Array();
      _messageQueueMax = MESSAGE_QUEUE_MAX;
    }

    /**
     *  Returns the mode of the HydnaStram
     *
     *  @return {String} current mode
     */
    public function get mode() : String {
      return _mode;
    }
    
    public function get messageQueueMax() : Number {
      return _messageQueueMax;
    }

    public function set messageQueueMax(value:Number) : void {
      _messageQueueMax = value;
    }
    
    public function write(data:ByteArray) : void {
      var message:ByteArray;

      if (_mode == HydnaDataStreamMode.READ) {
        throw new Error("Stream is not writable");
      }
      
      if (connected == false) {
        throw new Error("Stream is not connected.");
      }
      
      message = new ByteArray();
      message.writeShort(data.length + HydnaPacket.HEADER_SIZE);
      message.writeByte(HydnaPacket.EMIT);
      message.writeByte(0);
      message.writeBytes(addr.bytes, 0, addr.bytes.length);
      message.writeBytes(data, 0, data.length);

      // Try to send the message to server. The message is queued 
      // on failure.
      if (postMessage(message) == false) {

        // Check if queue is full. If so, remove the last message 
        // (hopefully) less important.
        if (_messageQueue.length == _messageQueueMax) {
          _messageQueue.pop();
        }
        
        _messageQueue.push(message);
      }
    }
    
    /**
     * Post message to underlying socket. Returns true on success else false.
     */
    private function postMessage(message:ByteArray) : Boolean {
      if (socket == null) {
        return false;
      }
      
      try {
        socket.writeBytes(message, 0, message.length);
        socket.flush();
      } catch (error:IOErrorEvent) {
        // Something wen't terrible wrong. Queue message and wait 
        // for a reconnect.
        return false;
      }
      
      return true;
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
     * Handles socket connect events. Send the OPEN control packet to 
     * Hydna network.
     */
    override internal function internalConnect() : void {
      super.internalConnect();
      var token:String = this._token;
      var packetLength:Number = HydnaPacket.HEADER_SIZE + 1;
      var tokenBuffer:ByteArray;
      var message:ByteArray;
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

      tokenBuffer = new ByteArray();

      if (token == null) {
        tokenBuffer.writeByte(0);
        packetLength += 1;
      } else {
        
        // TODO: Do not use writeUTF. Will send garbage chars in begining of
        // buffer.
        tokenBuffer.writeUTF(token);
        packetLength += tokenBuffer.length;
      }
      
      message = new ByteArray();
      message.writeShort(packetLength);
      message.writeByte(HydnaPacket.OPEN);
      message.writeByte(0);
      message.writeBytes(originalAddr.bytes, 0, addr.bytes.length);
      message.writeByte(mode);
      message.writeBytes(tokenBuffer, 0, tokenBuffer.length);

      try {
        socket.writeBytes(message, 0, message.length);
        socket.flush();
      } catch (error:IOErrorEvent) {
        // Ignore errors. Stream is automaticlly sending a new open when
        // reconnected.
        return;
      }
      
      // Empty message queue
      while ((message = _messageQueue.pop())) {
        if (!postMessage(message)) {
          _messageQueue.unshift(message);
          break;
        }
      }
      
    }
    
    override public function close() : Boolean {
      var message:ByteArray;
      
      if (super.close()) {
        if (socket.connected) {
          message = new ByteArray();
          
          message.writeShort(HydnaPacket.HEADER_SIZE);
          message.writeByte(HydnaPacket.CLOSE);
          message.writeBytes(addr.bytes, 0, addr.bytes.length);
          
          try {
            socket.writeBytes(message, 0, message.length);
            socket.flush();
          } catch(error:IOErrorEvent) {
            // IOErrorEvent internalClose. else wait for an interrupt packet.
            internalClose(0);
          }
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