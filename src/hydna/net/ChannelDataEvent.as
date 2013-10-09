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
  import flash.utils.ByteArray;

  public class ChannelDataEvent extends Event {

    public static const DATA:String = "data";

    private var _data:ByteArray;
    private var _message:String;
    private var _priority:Number


    public function ChannelDataEvent(priority:Number,
                                     data:ByteArray,
                                     message:String=null) {
      super(DATA, false, false);

      _priority = priority;
      _data = data;
      _message = message;
    }


    public function get priority() : Number {
      return _priority;
    }


    /**
     *  Returns the data associated with this ChannelDataEvent instance.
     */
    public function get data() : ByteArray {
      return _data;
    }


    /**
     *  Returns the message associated with this ChannelCloseEvent
     *  instance. The property is null if message was of type binary.
     */
    public function get message() : String {
      return _message;
    }

  }

}