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
  
  import hydna.net.Addr;
  
  internal class Message extends ByteArray {
    
    internal static const HEADER_SIZE:Number = 0x08;
    
    // Client opcodes
    internal static const OPEN:Number =  0x01;
    internal static const CLOSE:Number =  0x02;
    internal static const EMIT:Number =  0x03;
    internal static const SEND:Number =  0x04;
    
    // Server opcodes
    internal static const OPENRESP:Number = 0x01;
    internal static const DATA:Number = 0x03;
    internal static const SIGNAL:Number = 0x04;
    internal static const END:Number = 0x0E;
    internal static const ERROR:Number = 0x0F;


    public function Message( addr:Addr
                           , op:uint
                           , flag:uint=0
                           , payload:ByteArray=null
                           , offset:uint=0
                           , length:uint=0) {
      var fixedOffset:Number = offset;
      var fixedLength:Number = length;
      var payloadLength:Number;
      
      if (payload == null) {
        fixedLength = 0;
      } else if (fixedOffset > 0 && fixedLength == 0) {
        fixedLength = payload.length - fixedOffset;
        if (fixedLength < 0) {
          fixedOffset = 0;
          fixedLength = payload.length;
        }
      } else if (fixedOffset == 0 && fixedLength == 0) {
        fixedOffset = 0;
        fixedLength = payload.length;
      } else if (fixedOffset + fixedLength > payload.length) {
        fixedOffset = 0;
        fixedLength = payload.length;
      } 
      
      writeShort(fixedLength + HEADER_SIZE);
      writeByte(0); // Reserved
      writeUnsignedInt(addr.stream);
      writeByte(op << 4 | flag);
      if (payload != null) {
        writeBytes(payload, fixedOffset, fixedLength);
      }
    }
  }
  
}