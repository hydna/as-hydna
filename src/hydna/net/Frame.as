// Frame.as

/**
 *        Copyright 2010-2013 Hydna AB. All rights reserved.
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

  internal class Frame extends ByteArray {

    internal static const HEADER_SIZE:Number = 0x05;

    // Opcodes
    internal static const KEEPALIVE:Number = 0x00;
    internal static const OPEN:Number = 0x01;
    internal static const DATA:Number = 0x02;
    internal static const SIGNAL:Number = 0x03;
    internal static const RESOLVE:Number = 0x04;

    // Open Flags
    internal static const OPEN_SUCCESS:Number = 0x0;

    // Content types
    internal static const PAYLOAD_UTF:Number = 0x0;
    internal static const PAYLOAD_BIN:Number = 0x1;

    // Signal Flags
    internal static const SIG_EMIT:Number = 0x0;
    internal static const SIG_END:Number = 0x1;

    // Upper payload limit
    internal static const PAYLOAD_MAX_SIZE:Number = 0xFFFF - HEADER_SIZE;

    internal static const FLAG_BITMASK:Number = 0x7;

    internal static const OP_BITPOS:Number = 3;
    internal static const OP_BITMASK:Number = (0x7 << OP_BITPOS);

    internal static const CTYPE_BITPOS:Number = 6;
    internal static const CTYPE_BITMASK:Number = (0x1 << CTYPE_BITPOS);


    public function Frame(id:uint,
                          ctype:uint,
                          op:uint,
                          flag:uint=0,
                          payload:ByteArray=null,
                          offset:uint=0,
                          length:uint=0) {
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

      if (fixedLength > PAYLOAD_MAX_SIZE) {
        throw new RangeError("Buffer overflow");
      }

      writeShort(fixedLength + HEADER_SIZE);
      writeUnsignedInt(id);
      writeByte((ctype << CTYPE_BITPOS) | (op << OP_BITPOS) | flag);

      if (payload != null) {
        writeBytes(payload, fixedOffset, fixedLength);
      }
    }

    public function get id() : uint {
      var pos:uint = this.position;
      var value:uint;

      this.position = 2;
      value = this.readUnsignedInt();
      this.position = pos;

      return value;
    }

    public function set id(value:uint) : void {
      var pos:uint = this.position;

      this.position = 2;
      this.writeUnsignedInt(value);
      this.position = pos;
    }
  }

}
