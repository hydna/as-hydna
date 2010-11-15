// HydnaErrorEvent.as

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
    
    public static function fromErrorCode( code:Number
                                        , errorMessage:String=null) 
                                        : StreamErrorEvent {
      var message:String;
      
      switch (code) {
        default:
        case 0x01: message = "Unknown Error"; break;

        // Stream related error codes
        case 0x02: message = "Bad message format"; break;
        case 0x03: message = "Multiple ACK request to same addr"; break;
        case 0x04: message = "Invalid operator"; break;
        case 0x05: message = "Invalid operator flag"; break;
        case 0x06: message = "Stream is already open"; break;
        case 0x07: message = "Stream is not writable"; break;
        case 0x08: message = "Stream is not available"; break;
        case 0x09: message = "Server is busy"; break;
        case 0x0A: message = "Bad handshake packet"; break;
        case 0x0F: message = "Invalid domain addr"; break;
        
        // Handshake related error codes
        case 0x10: message = "Server is busy"; break;
        case 0x12: message = "Invalid Domain"; break;
        
        // OPENRESP releated error codes
        case 0x101: message = "Not found"; break;
        case 0x10F: message = ""; break; // User-defined

        // End releated error codes
        // case 0x111: message = "End of transmission"; break;
        // case 0x11F: message = ""; break; // User-defined.
        
        // Library specific error codes
        case 0x1001: message = "Server responed with bad handshake"; break
        case 0x1002: message = "Server sent malformed packet"; break
        case 0x1003: message = "Server sent invalid open response"; break
        case 0x1004: message = "Server sent to non-open stream"; break
        case 0x1005: message = "Server redirected to open stream"; break
        case 0x1006: message = "Security error"; break;
        case 0x1007: message = "Stream already open."; break;
        case 0x100F: message = "Disconnected from server"; break
      }
      
      return new StreamErrorEvent(errorMessage || message, code);
    }
  }
}