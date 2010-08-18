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
  import com.hydna.HydnaPacket;

  public class HydnaStream extends EventDispatcher {

    private var _type:String;
    private var _addr:HydnaAddr = null;
    private var _originalAddr:HydnaAddr = null;
    private var _socket:Socket = null;
    private var _connected:Boolean = false;
    private var _closing:Boolean = false;
    
    /**
     * Initializes a new HydnaStream instance
     */
    public function HydnaStream(type:String,
                                addr:HydnaAddr) {
      _type = type;
      _addr = addr;
      _originalAddr = addr;
    }

    /**
     *  Returns the underlying {flash.net.Socket} Socket instance.
     */
    public function get socket() : Socket {
      return _socket;
    }
    
    /**
     *  Return the connected state for this HydnaStream instance.
     */
    public function get connected() : Boolean {
      return _connected;
    }

    /**
     *  Return the closing state for this HydnaStream instance.
     */
    public function get closing() : Boolean {
      return _closing;
    }

    /**
     *  Return the connected state for this HydnaStream instance.
     */
    internal function setConnected(value:Boolean) : void {
      _connected = value;
    }
    
    /**
     *  Return the connected state for this HydnaStream instance.
     */
    internal function setSocket(streamSocket:Socket) : void {
      
      if (_socket != null) {
        _socket.removeEventListener(Event.CONNECT, internalConnect);
      }
      
      _socket = streamSocket;
      
      if (_socket == null) {
        return;
      }
      
      // Check if socket already is connect, if so, fire internalConnect else
      // wait for a connection.
      if (_socket.connected) {
        internalConnect();
      } else {
        _socket.addEventListener(Event.CONNECT, internalConnect);
      }
    }

    /**
     *  Returns the type of this HydnaStream instance. Valid values are:
     *  HydnaStreamType.DATA, HydnaStreamType.PING and HydnaStreamType.META.
     */
    public function get type() : String {
      return _type;
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
     *  Set's the HydnaAddr for this instance.
     */
    internal function setAddr(value:HydnaAddr) : void {
      _addr = value;
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
     *  Closes the stream
     */
    public function close() : Boolean {
      if (_connected == false || _closing == true) return false;
      _closing = true;
      return true;
    }
    
    internal function internalConnect() : void { }
    
    internal function internalClose(error:Number=0) : void {
      throw new Error("Not Implemented");
    }
    
  }
  
}