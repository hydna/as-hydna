// StreamErrorEvent.as

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
  
  import flash.events.ErrorEvent;
  import flash.utils.ByteArray;

  public class StreamErrorEvent extends ErrorEvent {
    
    private var _code:Number = 0;
    
    /**
     *  Constructor for the StreamErrorEvent
     *
     *  @param {Number} code The error code for this event. Default is 0
     *  @param {String} message An optional message to associate with the
     *                          event.
     */
    public function StreamErrorEvent(message:String, code:Number=0) {
      super(ErrorEvent.ERROR, false, false, message);
      _code = code;
    }
        
    public function get code() : Number {
      return _code;
    }
    
    public static function fromError(error:Error): StreamErrorEvent {
      return new StreamErrorEvent(error.message, 0xFFFF);
    }

    public static function fromEvent(event:ErrorEvent): StreamErrorEvent {
      return new StreamErrorEvent(event.text, 0xFFFF);
    }
    
    internal static function fromHandshakeError(flag:Number) : StreamErrorEvent {
      var code:Number;
      var msg:String;
      
      switch (flag) {
        case Packet.HANDSHAKE_UNKNOWN:
          code = Packet.HANDSHAKE_UNKNOWN;
          msg = "Unknown handshake error";
          break;
        case Packet.HANDSHAKE_SERVER_BUSY:
          msg = "Handshake failed, server is busy";
          break;
        case Packet.HANDSHAKE_BADFORMAT:
          msg = "Handshake failed, bad format sent by client";
          break;
        case Packet.HANDSHAKE_HOSTNAME:
          msg = "Handshake failed, invalid hostname";
          break;
        case Packet.HANDSHAKE_PROTOCOL:
          msg = "Handshake failed, protocol not allowed";
          break;
        case Packet.HANDSHAKE_SERVER_ERROR:
          msg = "Handshake failed, server error";
          break;
      }
      
      return new StreamErrorEvent(msg, code);
    }
    
    internal static function fromOpenError( flag:Number
                                          , data:ByteArray
                                          ) : StreamErrorEvent {
      var code:Number;
      var msg:String;
      
      code = flag;
      
      if (data != null || data.length != 0) {
        msg = data.readUTFBytes(data.length);
      }

      switch (code) {
        case Packet.OPEN_FAIL_NA:
          msg = msg || "Failed to open stream, not available";
          break;
        case Packet.OPEN_FAIL_MODE:
          msg = msg || "Not allowed to open stream with specified mode";
          break;
        case Packet.OPEN_FAIL_PROTOCOL:
          msg = msg || "Not allowed to open stream with specified protocol";
          break;
        case Packet.OPEN_FAIL_HOST:
          msg = msg || "Not allowed to open stream from host";
          break;
        case Packet.OPEN_FAIL_AUTH:
          msg = msg || "Not allowed to open stream with credentials";
          break;
        case Packet.OPEN_FAIL_SERVICE_NA:
          msg = msg || "Failed to open stream, service is not available";
          break;
        case Packet.OPEN_FAIL_SERVICE_ERR:
          msg = msg || "Failed to open stream, service error";
          break;
        
        default:
        case Packet.OPEN_FAIL_OTHER:
          code = Packet.OPEN_FAIL_OTHER;
          msg = msg || "Failed to open stream, unknown error";
          break;
      }
      
      return new StreamErrorEvent(msg, code);
    }
    
    internal static function fromSigError( flag:Number
                                         , data:ByteArray
                                         ) :  StreamErrorEvent {
      var code:Number;
      var msg:String;
      
      code = flag;
      
      if (data != null || data.length != 0) {
        msg = data.readUTFBytes(data.length);
      }
      
      switch (code) {
        case Packet.SIG_ERR_PROTOCOL:
          msg = msg || "Protocol error";
          break;
        case Packet.SIG_ERR_OPERATION:
          msg = msg || "Operational error";
          break;
        case Packet.SIG_ERR_LIMIT:
          msg = msg || "Limit error";
          break;
        case Packet.SIG_ERR_SERVER:
          msg = msg || "Server error";
          break;
        case Packet.SIG_ERR_VIOLATION:
          msg = msg || "Violation error";
          break;
        
        default:
        case Packet.SIG_ERR_OTHER:
          code = Packet.SIG_ERR_OTHER;
          msg = msg || "Unknown error";
          break;
      }
      
      return new StreamErrorEvent(msg, code);
    }
  }
}