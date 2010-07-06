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
  import com.hydna.HydnaDataStream;
  import com.hydna.HydnaErrorEvent;
  import com.hydna.HydnaDataStreamMode;
  
  public class Hydna extends EventDispatcher {
    
    public static const MAJOR_VERSION:Number = 1;
    public static const MINOR_VERSION:Number = 0;
    
    public static const DEFAULT_HOST:String = "127.0.0.1";
    public static const DEFAULT_PORT:Number = 7015;
    
    private var _socket:Socket = null;
    private var _streams:Object = new Object();
    private var _finalized:Boolean = false;
    private var _shutdown:Boolean = false;

    private var receiveBuffer:ByteArray = new ByteArray();
    
    /**
     *  Creates a Hydna object. If no parameters are specified, the default
     *  host and port is used. 
     *
     *  @param {String} host The name of the host to connect to. Leave blank
     *                       to use default host.
     *  @param {Number} port The port number to connect to. Leave blank to
     *                       use default port.
     *  @return {com.hydna.Hydna} the newly created Hydna instance.
     */
    public static function connect(host:String = DEFAULT_HOST, 
                                   port:uint = DEFAULT_PORT) : Hydna {
      return new Hydna(host, port);
    }
    
    /**
     *  Creates a Hydna object. 
     *
     *  @param {String} host The name of the host to connect to. 
     *  @param {Number} port The port number to connect to. 
     */
    public function Hydna(host:String, port:uint) {
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
     *  Indicates whether this Hydna object is currently connected. A call to 
     *  this property returns a value of true if currently connected, or false 
     *  otherwise.
     */
    public function get connected() : Boolean {
      return _socket.connected;
    }
    
    /**
     *  Opens a stream on the Hydna network.
     *
     */
    public function open(addr:HydnaAddr, 
                         mode:String = HydnaDataStreamMode.READ, 
                         token:String = null) : HydnaDataStream {
      var stream:HydnaDataStream = null;
      var addrValue:String = addr.chars;
      
      switch (mode) {
        case HydnaDataStreamMode.READ:
        case HydnaDataStreamMode.WRITE: 
        case HydnaDataStreamMode.READWRITE: 
          break;
          
        default: throw new Error("Illegal mode");
      }
      
      if (_streams[addrValue]) {
        return _streams[addrValue];
      }
      
      stream = new HydnaDataStream(_socket, addr, mode, token);
      stream.addEventListener(Event.OPEN, streamOpenHandler);
      stream.addEventListener(Event.CLOSE, streamCloseHandler);
      
      _streams[addrValue] = stream;
      
      stream.open();
      
      return stream;
    }
    
    /**
     *  Closes connection to the Hydna Network.
     *
     *  @param {Boolean} graceful Closes each individual stream before 
     *                            final shutdown.
     */
    public function shutdown(graceful:Boolean = true) : void {
      var stream:HydnaStream;
      
      if (_shutdown) return;
      
      if (graceful) {
        finalize();
      } else {
        
        for (var key:String in _streams) {
          stream = HydnaStream(_streams[key]);

          if (stream != null && stream.connected) {
            stream.removeEventListener(Event.OPEN, streamOpenHandler);
            stream.removeEventListener(Event.CLOSE, streamCloseHandler);
          }
        }
        
        _streams = new Object();
        _shutdown = true;
        
        if (_socket.connected) {
          _socket.close();
        }
      }
    }

    private function streamOpenHandler(event:Event) : void {
      var stream:HydnaDataStream = HydnaDataStream(event.target);
      
      if (stream.addr.equals(stream.originalAddr) == false) {
        delete _streams[stream.originalAddr.chars];
        _streams[stream.addr] = stream;
      }
    }
    
    private function streamCloseHandler(event:Event) : void {
      var stream:HydnaStream = HydnaStream(event.target);

      delete _streams[stream.addr.chars];
      
      stream.removeEventListener(Event.OPEN, streamOpenHandler);
      stream.removeEventListener(Event.CLOSE, streamCloseHandler);
    }
    
    private function connectHandler(event:Event) : void {
      dispatchEvent(event);
      trace("connectHandler: " + event);
    }
    
    private function closeHandler(event:Event) : void {
      trace("closeHandler: " + event);
      if (_finalized || _shutdown) {
        dispatchEvent(event);
      } else {
        finalize();
      }
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
      var packetAddr:String; 
      var stream:HydnaStream = null;
      var index:Number;
      
      _socket.readBytes(receiveBuffer, 
                        receiveBuffer.length, 
                        _socket.bytesAvailable);
      
      while (receiveBuffer.length > HydnaPacket.HEADER_LENGTH) {

        receiveBuffer.position = 0;
        packetAddr = "";
        index = 8;
                
        packetLength = receiveBuffer.readUnsignedShort();

        if (receiveBuffer.bytesAvailable < (packetLength - 2)) {
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
        } else {

          switch (packetFlag) {

            case HydnaPacket.OPENSTAT:
              processOpenStatPacket(stream, receiveBuffer, packetLength);
              break;

            case HydnaPacket.DATA:
              processDataPacket(stream, receiveBuffer, packetLength);
              break;

            case HydnaPacket.INTERRUPT:
              processInterruptPacket(stream, receiveBuffer, packetLength);
              break;
          }
        }

        if (receiveBuffer.length > packetLength) {
          var newSize:Number = receiveBuffer.length - packetLength;
          var tempBuffer:ByteArray = new ByteArray();
          receiveBuffer.readBytes(tempBuffer, 0, newSize);
          receiveBuffer = tempBuffer;
        } else {
          receiveBuffer = new ByteArray();
        }
        
      }
    }
    
    private function processOpenStatPacket(stream:HydnaStream,
                                           buffer:ByteArray,
                                           packetLength:Number) : void {
      var dataStream:HydnaDataStream = HydnaDataStream(stream);
      var dataLength:Number = packetLength - HydnaPacket.HEADER_LENGTH;
      var index:Number = 8;
      var responseAddr:String = "";
      var code:Number;
      var event:Event;

      if (dataStream == null) {
        return;
      }
      
      if (dataLength < 9) {
        // Ignore packet, invalid format
        return;
      }

      code = buffer.readUnsignedByte();

      while (index--) {
        responseAddr += String.fromCharCode(buffer.readUnsignedByte());
      }
      
      if (code == 0) {
        dataStream.setConnected(true);
        dataStream.setAddr(HydnaAddr.fromChars(responseAddr));
        event = new Event(Event.OPEN);
      } else {
        event = new HydnaErrorEvent(code);
      }
      
      dataStream.dispatchEvent(event);
    }
    
    private function processDataPacket(stream:HydnaStream,
                                       buffer:ByteArray,
                                       packetLength:Number) : void {
      var dataStream:HydnaDataStream = HydnaDataStream(stream);
      var dataLength:Number = packetLength - HydnaPacket.HEADER_LENGTH;
      var dataBuffer:ByteArray;
      var event:HydnaStreamEvent;
      
      if (dataStream == null) {
        return;
      }
      
      dataBuffer = new ByteArray();
      
      buffer.readBytes(dataBuffer, 0, dataLength);
      event = new HydnaStreamEvent(HydnaStreamEvent.DATA, 0, dataBuffer);
      dataStream.dispatchEvent(event);
    }

    private function processInterruptPacket(stream:HydnaStream,
                                            buffer:ByteArray,
                                            packetLength:Number) : void {
      var dataStream:HydnaDataStream = HydnaDataStream(stream);
      var dataLength:Number = packetLength - HydnaPacket.HEADER_LENGTH;
      var event:HydnaStreamEvent;
      var code:Number;
      
      if (dataStream == null) {
        return;
      }

      if (dataLength < 2) {
        // Ignore packet, invalid format
        return;
      }
      
      code = buffer.readUnsignedShort();
      dataStream.internalClose(code);
    }

    private function finalize() : void {
      var socket:Socket = _socket;
      var connectedStreams:Array = new Array();
      var stream:HydnaStream;
      var index:Number;
      
      function eventloop() : void {
        connectedStreams.pop();
        
        if (connectedStreams.length == 0) {
          _finalized = true;
          if (socket.connected) {
            socket.close();
          } else {
            dispatchEvent(new Event(Event.CLOSE));
          }
        }
      }
      
      for (var key:String in _streams) {
        stream = HydnaStream(_streams[key]);

        if (stream != null && stream.connected) {
          stream.addEventListener(Event.CLOSE, eventloop);
          connectedStreams.push(stream);
        }

      }
      
      index = connectedStreams.length;
      
      while (index--) {
        stream = HydnaStream(connectedStreams[index]);
        stream.close();
      }

    }
  }
  
}