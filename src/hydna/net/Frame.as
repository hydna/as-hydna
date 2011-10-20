// Frame.as

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

  internal class Frame extends ByteArray {

    internal static const HEADER_SIZE:Number = 0x08;

    // Opcodes
    internal static const OPEN:Number = 0x01;
    internal static const DATA:Number = 0x02;
    internal static const SIGNAL:Number = 0x03;

    // Handshake flags
    internal static const HANDSHAKE_UNKNOWN:Number = 0x01;
    internal static const HANDSHAKE_SERVER_BUSY:Number = 0x02;
    internal static const HANDSHAKE_BADFORMAT:Number = 0x03;
    internal static const HANDSHAKE_HOSTNAME:Number = 0x04;
    internal static const HANDSHAKE_PROTOCOL:Number = 0x05;
    internal static const HANDSHAKE_SERVER_ERROR:Number = 0x06;

    // Open Flags
    internal static const OPEN_SUCCESS:Number = 0x0;
    internal static const OPEN_REDIRECT:Number = 0x1;
    internal static const OPEN_FAIL_NA:Number = 0x8;
    internal static const OPEN_FAIL_MODE:Number = 0x9;
    internal static const OPEN_FAIL_PROTOCOL:Number = 0xa;
    internal static const OPEN_FAIL_HOST:Number = 0xb;
    internal static const OPEN_FAIL_AUTH:Number = 0xc;
    internal static const OPEN_FAIL_SERVICE_NA:Number = 0xd;
    internal static const OPEN_FAIL_SERVICE_ERR:Number = 0xe;
    internal static const OPEN_FAIL_OTHER:Number = 0xf;

    // Signal Flags
    internal static const SIG_EMIT:Number = 0x0;
    internal static const SIG_END:Number = 0x1;
    internal static const SIG_ERR_PROTOCOL:Number = 0xa;
    internal static const SIG_ERR_OPERATION:Number = 0xb;
    internal static const SIG_ERR_LIMIT:Number = 0xc;
    internal static const SIG_ERR_SERVER:Number = 0xd;
    internal static const SIG_ERR_VIOLATION:Number = 0xe;
    internal static const SIG_ERR_OTHER:Number = 0xf;

    // Upper payload limit (10kb)
    internal static const PAYLOAD_MAX_LIMIT:Number = 10 * 1024;

    public function Frame( ch:uint
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

      if (fixedLength > PAYLOAD_MAX_LIMIT) {
        throw new RangeError("Payload max limit reached.");
      }

      writeShort(fixedLength + HEADER_SIZE);
      writeByte(0); // Reserved
      writeUnsignedInt(ch);
      writeByte(op << 4 | flag);
      if (payload != null) {
        writeBytes(payload, fixedOffset, fixedLength);
      }
    }

    public function get channel() : uint {
      var pos:uint = this.position;
      var value:uint;

      this.position = 2;
      value = this.readUnsignedInt();
      this.position = pos;

      return value;
    }

    public function set channel(value:uint) : void {
      var pos:uint = this.position;

      this.position = 2;
      this.writeUnsignedInt(value);
      this.position = pos;
    }
  }

}