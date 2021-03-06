// ChannelDataEvent.as

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


  import flash.events.Event;
  import flash.errors.EOFError;
  import flash.utils.ByteArray;


  public class ChannelEvent extends Event {

    /**
     * The OPEN constant defines the value of the type property of
     * an open event object.
     */
    public static const OPEN:String = "open";

    /**
     * The DATA constant defines the value of the type property of
     * an data event object.
     */
    public static const DATA:String = "data";

    /**
     * The SIGNAL constant defines the value of the type property of
     * an signal event object.
     */
    public static const SIGNAL:String = "signal";

    /**
     * The CLOSE constant defines the value of the type property of
     * an close event object.
     */
    public static const CLOSE:String = "close";

    private var _data:ByteArray = null;
    private var _message:String = null;
    private var _ctype:Number = Frame.PAYLOAD_UTF;


    public function ChannelEvent(type:String,
                                 ctype:Number,
                                 data:ByteArray) {
      super(type, false, true);
      _ctype = ctype;
      _data = data;
    }


    /**
     *  Returns the data associated with this ChannelEvent instance.
     */
    public function get data() : ByteArray {
      return _data;
    }


    /**
     *  Returns the message associated with this ChannelEvent
     *  instance. The property is null if message was of type binary or 
     *  if an encoding error occured.
     */
    public function get message() : String {
      var oldpos:uint;

      if (_message != null) {
        return _message;
      }

      if (_data == null) {
        return null;
      }

      if (_ctype == Frame.PAYLOAD_UTF) {
        try {
          oldpos = _data.position;
          _message = _data.readUTFBytes(_data.length);
        } catch (err:EOFError) {
          _message = null;
        } finally {
          _data.position = oldpos;
        }
      }

      return _message;
    }

  }

}