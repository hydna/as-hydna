// Hydna.as

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
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  
  import com.hydna.HydnaStream;
  import com.hydna.HydnaStreamMode;
  
  public class Hydna extends EventDispatcher{
    
    private var _connceted:Boolean = false;
    private var _socket:Socket = null;
    private var _streams:Object = new Object();

    private var receiveBuffer:ByteArray = new ByteArray();
    
    public static function connect(host:String = null, 
                                            port:uint = 0) : Hydna {
      return new Hydna(host, port);
    }
    
    /**
     * 
     */
    public function Hydna(host:String = null, port:uint = 0) {
      super();

      _socket = new Socket(host, port);
      
      _socket.addEventListener(Event.CLOSE, closeHandler);
      _socket.addEventListener(Event.CONNECT, connectHandler);
      _socket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
      _socket.addEventListener(ProgressEvent.SOCKET_DATA, receive);
      _socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, 
                               securityErrorHandler);
    }
    
    /**
     *  Opens a stream on network.
     *
     */
    public function open(addr:HydnaAddr, 
                         mode:String = HydnaStreamMode.READ, 
                         token:String = null) : HydnaStream {
      var stream:HydnaStream = null;
      var addrValue:String = addr.chars;
      
      switch (mode) {
        case HydnaStreamMode.READ:
        case HydnaStreamMode.WRITE: 
        case HydnaStreamMode.READWRITE: 
          break;
          
        default: throw new Error("Illegal mode");
      }
      
      if (_streams[addrValue]) {
        return _streams[addrValue];
      }
      
      stream = new HydnaStream(_socket, addr, mode, token);
      
      _streams[addrValue] = stream;
      
      stream.open();
      
      return stream;
    }
    
    private function connectHandler(event:Event) : void {
      dispatchEvent(event);
      trace("connectHandler: " + event);
    }
    
    private function closeHandler(event:Event) : void {
      dispatchEvent(event);
      trace("closeHandler: " + event);
    }

    private function ioErrorHandler(event:IOErrorEvent) : void {
      trace("ioErrorHandler: " + event);      
    }

    private function securityErrorHandler(event:SecurityErrorEvent) : void {
      trace("securityErrorHandler: " + event);
    }

    private function receive(event:ProgressEvent) : void {
      var packetLength:Number;
      var packetFlag:Number;
      var packetReserved:Number;
      var packetAddr:String = ""; 
      var responseAddr:String = ""; 
      var stream:HydnaStream = null;
      var stateCode:Number = 0;
      var index:Number = 8;
      
      trace("socketDataHandler: " + event); 
      
      _socket.readBytes(receiveBuffer, 
                        receiveBuffer.length, 
                        _socket.bytesAvailable);
      
      receiveBuffer.position = 0;
      
      if (receiveBuffer.length < HydnaPacket.HEADER_LENGTH) {
        return;
      }
      
      packetLength = receiveBuffer.readUnsignedShort();
      
      if (receiveBuffer.bytesAvailable < (packetLength - HydnaPacket.HEADER_LENGTH)) {
        return;
      }

      packetFlag = receiveBuffer.readUnsignedByte();
      packetReserved = receiveBuffer.readUnsignedByte();
      
      while (index--) {
        packetAddr += String.fromCharCode(receiveBuffer.readUnsignedByte());
      }
      
      stream = _streams[packetAddr];
      
      if (!stream) {
        // Ignore packet
        trace("ignore packet, stream not found");
        packetFlag = 0;
      }
      
      switch (packetFlag) {

        case HydnaPacket.OPENSTAT:
        
          stateCode = receiveBuffer.readUnsignedByte();

          index = 8;

          while (index--) {
            responseAddr += String.fromCharCode(receiveBuffer.readUnsignedByte());
          }
          
          stream.setOpenState(stateCode, responseAddr);
          
          break;
          
        case HydnaPacket.DATA:
          stream.processData(receiveBuffer, packetLength - HydnaPacket.HEADER_LENGTH);
          break;
          
        case HydnaPacket.INTERRUPT:
          trace("TODO!");
          break;
      }
      
      if (receiveBuffer.length > packetLength) {
        var newSize:Number = receiveBuffer.length - packetLength;
        var tempBuffer:ByteArray = new ByteArray();
        
        
        receiveBuffer.readBytes(tempBuffer, 0, newSize);
        receiveBuffer = tempBuffer;
      }
    }
    
  }
  
}