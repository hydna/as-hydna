// HydnaAddr.as

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
  
  import flash.utils.ByteArray;
  import flash.utils.Endian;
  
  public class Addr {
    
    public static var NULLADDR:Addr;
    
    private static const ADDR_SIZE:Number = 8;
    private static const COMP_SIZE:Number = 4;
    
    private static var ADDR_EXPR_RE:RegExp = 
            /^(?:([0-9a-f]{1,8})-|([0-9a-f]{1,8})-([0-9a-f]{1,8}))$/i;
    
    private static const DEFAULT_HOST:String = "flash.hydna.net";
    private static const DEFAULT_PORT:Number = 7010;
    
    private var _zone:uint;
    private var _stream:uint;
    private var _host:String;
    private var _port:Number = 80;
    
    {
      NULLADDR = new Addr(0, 0);
    }
    
    /**
     *  Addr constructor. 
     */
    public function Addr( zonecomp:uint
                        , streamcomp:uint
                        , host:String=null
                        , port:Number=DEFAULT_PORT) {
      _zone = zonecomp;
      _stream = streamcomp;
      _port = port;
      
      if (host == null) {
        _host = hexifyComponent(zonecomp) + "." + DEFAULT_HOST;
      }
    }

    /**
     *  Returns the underlying ByteArray instance for this HydnaAddr
     *
     *  @return {flash.utils.ByteArray} the underlying ByteArray.
     */
    public function get zone() : uint {
      return _zone;
    }

    public function get stream() : Number {
      return _stream;
    }
    
    public function get port() : Number {
      return _port;
    }

    public function get host() : String {
      return _host;
    }
        
    /**
     *  Compares this HydnaAddr instance with another one.
     *
     *  @return {Boolean} true if the two instances match, else false.
     */
    public function equals(addr:Addr) : Boolean {
      if (addr == null) return false;
      return _zone == addr._zone && _stream == addr._stream;
    }
    
    /**
     *  Converts this Addr instance into a hexa-decimal string.
     *
     */
    public function toHex() : String {
      return hexifyComponent(_zone) + "-" + hexifyComponent(_stream);
    }
    
    /**
     *  Converts the HydnaAddr into a hex-formated string representation.
     *
     */
    public function toString() : String {
      return toHex();
    }
    
    /**
     *  Creates a new Addr instance based on specified expression.
     */
    public static function fromExpr(expr:String) : Addr {
      var m:*;
      var zonecomp:uint;
      var streamcomp:uint = 0;
      
      trace("parse addr expr");
      
      if (expr == null) {
        throw new Error("Expected String");
      }
      
      m = expr.match(ADDR_EXPR_RE);
      
      if (m == null) {
        throw new Error("Bad expression");
      }
      
      if (m[1]) {
        zonecomp = parseInt(m[1], 16);
      } else {
        zonecomp = parseInt(m[2], 16);
        streamcomp = parseInt(m[3], 16);
      }
      
      return new Addr(zonecomp, streamcomp);
    }
    

    /**
      *  Initializes a new Addr instance from a ByteArray
      *
      *  @param {String} buffer The ByteArray that represents the address.
      */
    public static function fromByteArray(buffer:ByteArray) : Addr {
      return NULLADDR;
/*      var index:Number = SIZE;
      var chars:Array = new Array();
      var host:String;
      
      if (buffer == null || buffer.length != SIZE) {
        throw new Error("Expected a size " + SIZE + " ByteArray instance");
      }
      
      buffer.position = 0;
      
      while (index--) {
        chars.push(String.fromCharCode(buffer.readUnsignedByte()));
      }
      
      host = convertToHex(bytes, "", 0, PART_SIZE) + "." + DEFAULT_HOST;
      
      return new HydnaAddr(buffer, chars.join(""), host);
*/    }

    private static function hexifyComponent(comp:uint) : String {
      var h:String = comp.toString(16);
      
      while (h.length < 8) {
        h = "0" + h;
      }
      
      return h;
    }
  }
  
}