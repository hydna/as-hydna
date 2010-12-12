// ExtSocket.as

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
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;
  
  import hydna.net.Addr;
  import hydna.net.OpenRequest;
  import hydna.net.Packet;
  import hydna.net.Stream;
  import hydna.net.StreamDataEvent;
  import hydna.net.StreamErrorEvent;
  import hydna.net.StreamEmitEvent;
  import hydna.net.StreamCloseEvent;
  
  // Internal wrapper around flash.net.Socket
  internal class ExtSocket extends Socket {

    private static const HANDSHAKE_SIZE:Number = 8;
    private static const HANDSHAKE_RESP_SIZE:Number = 5;

    private static const SUCCESS:Number = 0;
    private static const CUSTOM_ERR_CODE:Number = 0xf;
    
    private static var availableSockets:Dictionary;

    private var _connecting:Boolean = false;
    private var _handshaked:Boolean = false;

    private var _receiveBuffer:ByteArray;
    private var _zone:uint;

    private var _pendingOpenRequests:Dictionary;
    private var _openStreams:Dictionary;
    private var _openWaitQueue:Dictionary;
    
    private var _streamRefCount:Number = 0;
    
    {
      availableSockets = new Dictionary();
    }
    
    // Return an available socket or create a new one.
    internal static function getSocket(addr:Addr) : ExtSocket {
      var socket:ExtSocket;
      
      if (availableSockets[addr.zone]) {
        socket = availableSockets[addr.zone];
      } else {
        socket = new ExtSocket(addr.zone);
        availableSockets[addr.zone] = socket;
      }
      
      return socket;
    }

    /**
     *  Initializes a new Stream instance
     */
    public function ExtSocket(zoneid:uint) {
      super();

      _zone = zoneid;
      
      _receiveBuffer = new ByteArray();

      _pendingOpenRequests = new Dictionary();
      _openStreams = new Dictionary();
      _openWaitQueue = new Dictionary();
      
      addEventListener(Event.CONNECT, connectHandler);
      addEventListener(Event.CLOSE, closeHandler);
      addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
      addEventListener(SecurityErrorEvent.SECURITY_ERROR, 
                       securityErrorHandler);
    }
    
    internal function get handshaked() : Boolean {
      return _handshaked;
    }
    
    // Internal method to keep track of no of streams that is associated 
    // with this connection instance.
    internal function allocStream() : void {
      _streamRefCount++;
      trace("allocStream: --> " + _streamRefCount);
    }
    
    // Decrease the reference count
    internal function deallocStream(addr:Addr=null) : void {
      trace("deallocStream: - > ")
      if (addr != null) {
        trace("deallocStream: - > delete stream of addr: " + addr.stream);
        delete _openStreams[addr.stream];
      }
      
      if (--_streamRefCount == 0) {
        trace("no more refs, destroy")
        destroy();
      }
    }

    // Request to open a stream. Return true if request went well, else
    // false.
    internal function requestOpen(request:OpenRequest) : Boolean {
      var streamcomp:uint = request.addr.stream;
      var queue:Array;

      if (_openStreams[streamcomp]) {
        return false;
      }

      if (_pendingOpenRequests[streamcomp]) {
        
        queue = _openWaitQueue[streamcomp] as Array;
        
        if (!queue) {
          _openWaitQueue[streamcomp] = queue = new Array();
        } 
        
        queue.push(request);
        
      } else if (!_handshaked) {
        _pendingOpenRequests[streamcomp] = request;
        if (!_connecting) {
          _connecting = true;
          trace("Connect to " + request.addr.host + ":" + request.addr.port);
          connect(request.addr.host, request.addr.port);
        }
      } else {
        writeBytes(request.packet);
        request.sent = true;

        try {
          flush();
        } catch (error:Error) {
          destroy(StreamErrorEvent.fromError(error));
          return false;
        }
      }
      
      return true;
    }
    
    // Try to cancel an open request. Returns true on success else
    // false.
    internal function cancelOpen(request:OpenRequest) : Boolean {
      var streamcomp:uint = request.addr.stream;
      var queue:Array;
      var index:Number;
      
      if (request.sent) {
        return false;
      }
      
      queue = _openWaitQueue[streamcomp] as Array;
      
      if (_pendingOpenRequests[streamcomp]) {
        delete _pendingOpenRequests[streamcomp];
        
        if (queue != null && queue.length)  {
          _pendingOpenRequests[streamcomp] = queue.pop();
        }
        
        return true;
      }
      
      // Should not happen...
      if (queue == null) {
        return false;
      }
      
      index = queue.indexOf(request);
      
      if (index != -1) {
        queue.splice(index, 1);
        return true;
      }
      
      return false;
    }
    
    //  Send a handshake packet and wait for a handshake
    // response packet in return.
    private function connectHandler(event:Event) : void {

      trace("in connect");

      addEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);

      writeMultiByte("DNA1", "us-acii");
      writeUnsignedInt(_zone);
      
      try {
        flush();
      } catch (error:Error) {
        destroy(StreamErrorEvent.fromError(error));
      }
    }

    // Handle the Handshake response packet.
    private function handshakeHandler(event:ProgressEvent) : void {
      var sentRequestCount:Number = 0;
      var request:OpenRequest;
      var code:Number;
      var errevent:Event;
      
trace("incomming handshake response");
      readBytes(_receiveBuffer, _receiveBuffer.length, bytesAvailable);

      if (_receiveBuffer.length < HANDSHAKE_RESP_SIZE) {
trace("buffer to small, expect " + _receiveBuffer.length + "/" + HANDSHAKE_SIZE);
        return;
      } else if (_receiveBuffer.length > HANDSHAKE_RESP_SIZE) {
        errevent = new StreamErrorEvent("Server responed with bad handshake");
        dispatchEvent(event);
        return;
      }
      
      if (_receiveBuffer.readMultiByte(HANDSHAKE_RESP_SIZE - 1, "us-acii") 
          !== "DNA1") {
        errevent = new StreamErrorEvent("Server responed with bad handshake");
        dispatchEvent(event);
        return;
      }
      
      if ((code = _receiveBuffer.readByte()) > 0) {
        errevent = StreamErrorEvent.fromHandshakeError(code);
        dispatchEvent(event);
        return;
      }

      _handshaked = true;
      _connecting = false;
      trace("bytesAvailable: " + bytesAvailable);
      _receiveBuffer = new ByteArray();
      removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);
      addEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);

      for (var key:Object in _pendingOpenRequests) {
        request = OpenRequest(_pendingOpenRequests[key]);
        writeBytes(request.packet);
        request.sent = true;
        trace("send open request")
      }

      try {
        flush();
      } catch (error:Error) {
        destroy(StreamErrorEvent.fromError(error));
      }
      
      trace("Handshake process is now done!");      
    }
    
    // Handles all incomming data.
    private function receiveHandler(event:ProgressEvent) : void {
      var stream:Stream = null;
      var size:uint;
      var addr:uint; 
      var op:Number;
      var flag:Number;
      var payload:ByteArray;
      
      readBytes(_receiveBuffer, _receiveBuffer.length, bytesAvailable);

      while (_receiveBuffer.bytesAvailable >= Packet.HEADER_SIZE) {
        size = _receiveBuffer.readUnsignedShort();

        if (_receiveBuffer.bytesAvailable < (size - 2)) {
          _receiveBuffer.position -= 2;
          trace("return!");
          return;
        }

        _receiveBuffer.readUnsignedByte(); // Reserved
        addr = _receiveBuffer.readUnsignedInt();
        op = _receiveBuffer.readUnsignedByte();
        flag = (op & 0xf);
        
        if (size - Packet.HEADER_SIZE) {
          payload = new ByteArray();
          _receiveBuffer.readBytes(payload, 0, size - Packet.HEADER_SIZE);
        }
        
        trace("incomming op: " + (op >> 4));
        
        switch ((op >> 4)) {

          case Packet.OPEN:
            trace("open response");
            processOpenPacket(addr, flag, payload);
            break;
            
          case Packet.DATA:
            trace("incomming data");
            processDataPacket(addr, flag, payload);
            break;
            
          case Packet.SIGNAL:
            processSignalPacket(addr, flag, payload);
            break;
        }
      }
      
      if (_receiveBuffer.bytesAvailable == 0) {
        _receiveBuffer = new ByteArray();
      }
    }

    // process an open packet
    private function processOpenPacket( addr:uint
                                      , flag:Number
                                      , payload:ByteArray) : void {
      var request:OpenRequest;
      var stream:Stream;
      var redirectaddr:uint;
      var event:Event;

      request = OpenRequest(_pendingOpenRequests[addr]);
      
      if (request == null) {
        event = new StreamErrorEvent("Server sent invalid open packet");
        destroy(event);
        return;
      }

      stream = request.stream;
      
      switch (flag) {

        case Packet.OPEN_SUCCESS:
          _openStreams[addr] = stream;
          stream.openSuccess(request.addr);
          break;
          
        case Packet.OPEN_REDIRECT:
          
          if (payload == null || payload.length < 4) {
            destroy(new StreamErrorEvent("Expected redirect addr from server"));
            return;
          }
          
          redirectaddr = payload.readUnsignedInt();
          
          if (_openStreams[redirectaddr]) {
            destroy(new StreamErrorEvent("Server redirected to open stream"));
            return;
          }
          
          _openStreams[redirectaddr] = stream;
          stream.openSuccess(new Addr(request.addr.zone, redirectaddr));
          break;
          
        case Packet.OPEN_FAIL_NA:
        case Packet.OPEN_FAIL_MODE:
        case Packet.OPEN_FAIL_PROTOCOL:
        case Packet.OPEN_FAIL_HOST:
        case Packet.OPEN_FAIL_AUTH:
        case Packet.OPEN_FAIL_SERVICE_NA:
        case Packet.OPEN_FAIL_SERVICE_ERR:
        case Packet.OPEN_FAIL_OTHER:
          event = StreamErrorEvent.fromOpenError(flag, payload);
          stream.destroy(event);
          break;

        default:
          destroy(new StreamErrorEvent("Server sent an unknown packet flag"));
          return;
      }

      if (_openWaitQueue[addr] && _openWaitQueue[addr].length) {
        
        // Destroy all pending request IF response wasn't a 
        // redirected stream.
        if (flag == Packet.OPEN_REDIRECT && redirectaddr == addr) {
          delete _pendingOpenRequests[addr];
          
          event = new StreamErrorEvent("Stream already open");
          
          while ((request = OpenRequest(_openWaitQueue[addr].pop()))) {
            request.stream.destroy(event);
          }
          return;
        }
        
        request = _openWaitQueue[addr].pop();
        _pendingOpenRequests[addr] = request;
        
        if (!_openWaitQueue[addr].length) {
          delete _openWaitQueue[addr];
        }
        
        writeBytes(request.packet);
        request.sent = true;
        
        try {
          flush();
        } catch (error:Error) {
          destroy(StreamErrorEvent.fromError(error));
        }
        
      } else {
        delete _pendingOpenRequests[addr];
      }
                                        
    }
    
    // process a data packet
    private function processDataPacket( addr:uint
                                      , flag:Number
                                      , payload:ByteArray) : void {
      var stream:Stream;
      var event:Event;

      if (payload == null || payload.length == 0) {
        destroy(new StreamErrorEvent("Zero data packet sent received"));
        return;
      }
      
      if (addr == Addr.BROADCAST_ADDR) {
        for (var key:String in _openStreams) {
          event = new StreamDataEvent(flag, payload);
          stream = Stream(_openStreams[key]);
          stream.dispatchEvent(event);
        }
      } else {
        stream = Stream(_openStreams[addr]);

        if (stream == null) {
          destroy(new StreamErrorEvent("Packet sent to unknown stream"));
          return;
        }
        
        event = new StreamDataEvent(flag, payload);

        stream.dispatchEvent(event);
      }
    }

    // process a signal packet
    private function processSignalPacket( addr:uint
                                        , flag:Number
                                        , payload:ByteArray) : void {
      var stream:Stream;
      var event:Event;
      
      switch (flag) {
        
        case Packet.SIG_EMIT:
        
          if (addr == Addr.BROADCAST_ADDR) {
            for (var key:String in _openStreams) {
              event = new StreamEmitEvent(payload);
              stream = Stream(_openStreams[key]);
              stream.dispatchEvent(event);
            }
          } else {
            event = new StreamEmitEvent(payload);
            
            stream = Stream(_openStreams[addr]);

            if (stream == null) {
              destroy(new StreamErrorEvent("Packet sent to unknown stream"));
              return;
            }

            stream.dispatchEvent(event);
          }
          break;
          
        case Packet.SIG_END:

          event = new StreamCloseEvent(payload);
          
          if (addr == Addr.BROADCAST_ADDR) {
            destroy(event);
          } else {
            stream = Stream(_openStreams[addr]);

            if (stream == null) {
              destroy(new StreamErrorEvent("Packet sent to unknown stream"));
              return;
            }
            
            stream.destroy(event);
          }
          break;
          
        case Packet.SIG_ERR_PROTOCOL:
        case Packet.SIG_ERR_OPERATION:
        case Packet.SIG_ERR_LIMIT:
        case Packet.SIG_ERR_SERVER:
        case Packet.SIG_ERR_VIOLATION:
        case Packet.SIG_ERR_OTHER:

          event = StreamErrorEvent.fromSigError(flag, payload);
          
          if (addr == Addr.BROADCAST_ADDR) {
            destroy(event);
          } else {
            stream = Stream(_openStreams[addr]);

            if (stream == null) {
              destroy(new StreamErrorEvent("Packet sent to unknown stream"));
              return;
            }
            
            stream.destroy(event);
          }
          break;
          
        default:
          destroy(new StreamErrorEvent("Server sent an unknown packet flag"));
          break;
        
      }
      
    }
    
    private function securityErrorHandler(event:SecurityErrorEvent) : void {
      destroy(new StreamErrorEvent("Security error"));
    }

    // Handles socket errors
    private function errorHandler(event:IOErrorEvent) : void {
      destroy(StreamErrorEvent.fromEvent(event));
    }

    // Handles socket close
    private function closeHandler(event:Event) : void {
      destroy(new StreamErrorEvent("Disconnected from server"));
    }
    
    // Finalize the Socket
    private function destroy(errorEvent:Event=null) : void {
      var event:Event = errorEvent;
			var pending:Dictionary = _pendingOpenRequests;
			var waitqueue:Dictionary = _openWaitQueue;
			var openstreams:Dictionary = _openStreams;
      var key:Object;
      var i:Number;
      var l:Number;
      var queue:Array;
      
      trace("in destroy");
      
      removeEventListener(Event.CONNECT, connectHandler);
      removeEventListener(Event.CLOSE, closeHandler);
      removeEventListener(ProgressEvent.SOCKET_DATA, handshakeHandler);
      removeEventListener(ProgressEvent.SOCKET_DATA, receiveHandler);
      removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
      removeEventListener(SecurityErrorEvent.SECURITY_ERROR, 
                                  securityErrorHandler);

			// So we do not trigger destroy multiple times.
			_pendingOpenRequests = null;
			_openWaitQueue = null;
			_openStreams = null;
      
      if (event == null) {
        event = new StreamErrorEvent("Unknown error");
      }

			if (pending != null) {
	      for (key in pending) {
	        OpenRequest(pending[key]).stream.destroy(event);
	      }
			}
      
			if (waitqueue != null) {
	      for (key in waitqueue) {
	        queue = waitqueue[key] as Array;
	        for (i = 0, l = queue.length; i < l; i++) {
	          OpenRequest(queue[i]).stream.destroy(event);
	        }
	      }
			}
			
			if (openstreams != null) {
	      for (key in openstreams) {
	        trace("destroy stream of key: " + key);
	        Stream(openstreams[key]).destroy(event);
	      }				
			}
      
      if (connected) {
        trace("destroy: call close");
        close();
      }
      
      
			if (availableSockets[_zone]) {
      	delete availableSockets[_zone];
			}

      trace("destroy: done");
    }
    
  }
}