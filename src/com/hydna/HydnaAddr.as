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
package com.hydna {
  
  import flash.utils.ByteArray;
  import flash.utils.Endian;
  
  public class HydnaAddr {
    
    public static var NULLADDR:HydnaAddr;
    
    public static var PAD_NONE:String = "NONE";
    public static var PAD_LEFT:String = "LEFT";
    public static var PAD_RIGHT:String = "RIGHT";
    
    public static const SIZE:Number = 16;
    
    private var _bytes:ByteArray;
    private var _chars:String;
    
    {
      NULLADDR = getNullAddr();
    }
    
    /**
     *  HydnaAddr Constructor. 
     */
    public function HydnaAddr(bytes:ByteArray, chars:String) {
      _bytes = bytes;
      _chars = chars;
      
      _bytes.position = 0;
    }
    
    /**
     *  Returns the underlying ByteArray instance for this HydnaAddr
     *
     *  @return {flash.utils.ByteArray} the underlying ByteArray.
     */
    public function get bytes() : ByteArray {
      return _bytes;
    }

    /**
     *  Returns the underlying chars instance for this HydnaAddr
     *
     *  @return {String} the underlying char buffer.
     */
    public function get chars() : String {
      return _chars;
    }
    
    /**
     *  Compares this HydnaAddr instance with another one.
     *
     *  @return {Boolean} true if the two instances match, else false.
     */
    public function equals(addr:HydnaAddr) : Boolean {
      if (addr == null) return false;
      return chars == addr.chars;
    }
    
    /**
     *  Converts this HydnaAddr into the hex
     *
     *  @param {String} delimiter The delimiter to use between keypairs. 
     *                            Default is ´:´.
     */
    public function toHex(delimiter:String = ":") : String {
      var result:Array = [];
      var index:Number = SIZE / 2;

      _bytes.position = 0;

      while (index--) {
        var comp:Number =  _bytes.readUnsignedShort();
        var stringComp:String = comp.toString(16);

        while (stringComp.length < 4) {
          stringComp = '0' + stringComp;
        }

        result.push(stringComp);
      }
      
      return result.join(delimiter);
    }
    
    /**
     *  Converts the HydnaAddr into a hex-formated string representation.
     *
     */
    public function toString() : String {
      return toHex();
    }
    
    /**
      *  Initializes a new Hydna Address from string char codes.
      *
      *  @param {String} buffer 8 chars that represents the address.
      */
    public static function fromChars(buffer:String) : HydnaAddr {
      var bytes:ByteArray = new ByteArray();
      
      if (buffer == null || buffer.length != SIZE) {
        throw new Error("buffer must be exactly " + SIZE + " chars.")
      }
      
      for (var i:Number = 0; i < buffer.length; i++) {
        bytes.writeByte(buffer.charCodeAt(i));
      }
      
      return new HydnaAddr(bytes, buffer);
    }

    /**
      *  Initializes a new Hydna Address from a ByteArray
      *
      *  @param {String} buffer The ByteArray that represents the address.
      */
    public static function fromByteArray(buffer:ByteArray) : HydnaAddr {
      var index:Number = SIZE;
      var chars:Array = new Array();
      
      if (buffer == null || buffer.length != SIZE) {
        throw new Error("Expected a size " + SIZE + " ByteArray instance");
      }
      
      buffer.position = 0;
      
      while (index--) {
        chars.push(String.fromCharCode(buffer.readUnsignedByte()));
      }
      
      return new HydnaAddr(buffer, chars.join(""));
    }
    
    /**
     *  Initializes a new Hydna Address based on hexa-formated string 
     *  representation.
     *
     *  @param {String} hexValue The hexa-formatted address to convert.
     *  @param {String} padding The padding routine to use. Default is 
     *                          HydnaAddr.PAD_NONE.
     *  @param {Number} expectedLength The expected length of the key. Default
     *                                 value is ´16´.
     */
    public static function fromHex(hexValue:String, 
                                   padding:String = "NONE", 
                                   expectedLength:Number = 16) : HydnaAddr {
      var hex:String = hexValue.replace(/\:/g, '');
      var bytes:ByteArray = new ByteArray();
      bytes.endian = Endian.BIG_ENDIAN;

      if ([PAD_LEFT, PAD_RIGHT, PAD_NONE].indexOf(padding) == -1) {
        throw new Error('Unknown padding method: ' + padding);
      }

      if (hex.length > SIZE * 2) {
        // Key is larger then 32 chars
        return null;
      }

      if (padding != PAD_NONE) {
        while (hex.length < SIZE * 2) {
          hex = padding == PAD_LEFT ? '0' + hex : hex + '0';
        }
      } else if (hex.length < expectedLength) {
        return null;
      }

      var comp:String = null;

      while (hex.length && (comp = hex.substr(0, 4))) {
       var intComp:Number = parseInt("0x" + comp);
       bytes.writeByte(Math.floor(intComp / 256) & 0xff);
       bytes.writeByte(intComp % 256);
       hex = hex.substr(4);
      }

      return fromByteArray(bytes);
    }
    
    internal static function getNullAddr() : HydnaAddr {
      var nulls:ByteArray = new ByteArray();
      
      for (var i:Number = 0; i < SIZE; i++) {
        nulls.writeByte(0);
      }
      
      return fromByteArray(nulls);
    }
    
  }
  
}