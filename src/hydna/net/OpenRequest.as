// OpenRequest.as

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

  import hydna.net.Frame;
  import hydna.net.Channel;

  // Internal class to handle open requests.
  internal class OpenRequest {

    internal var _channel:Channel;
    internal var _id:uint;
    internal var _path:String;
    internal var _mode:Number;
    internal var _sent:Boolean;
    internal var _token:String;

    public function OpenRequest(channel:Channel,
                                path:String,
                                mode:Number,
                                token:String) {
      _channel = channel;
      _path = path;
      _mode = mode;
      _token = token;
    }

    public function get channel() : Channel {
      return _channel;
    }

    public function set id(value:uint) : void {
      _id = value;
    }

    public function get id() : uint {
      return _id;
    }

    public function get path() : String {
      return _path;
    }

    public function get openFrame() : Frame {
      var frame:Frame;
      var token:ByteArray;

      token = new ByteArray();
      token.writeUTFBytes(decodeURIComponent(_token));

      frame = new Frame(_id, Frame.PAYLOAD_UTF, Frame.OPEN, _mode, token);

      return frame;
    }

    public function get resolveFrame() : Frame {
      var frame: Frame;
      var path:ByteArray;

      path = new ByteArray();
      path.writeUTFBytes(_path);

      frame = new Frame(0, Frame.PAYLOAD_UTF, Frame.RESOLVE, 0, path);

      return frame;
    }

    public function get sent() : Boolean {
      return _sent;
    }

    public function set sent(value:Boolean) : void {
      _sent = value;
    }
  }

}