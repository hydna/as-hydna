// HelloWorld.as

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

package {

  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.ErrorEvent;
  import flash.events.MouseEvent;
  import flash.text.TextField;
  import flash.text.TextFieldAutoSize;
  import flash.utils.ByteArray;
  import flash.system.Security;

  import flash.net.Socket;

  import hydna.net.Channel;
  import hydna.net.ChannelMode;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelSignalEvent;

  /**
   *  Hello world example Application
   *
   */
  public class HelloWorld extends Sprite {
    // Replace ADDRESS with your own domain
    public static const ADDRESS:String = "testing.hydna.net/test";

    public function HelloWorld() {
      var channel:Channel;

      Security.allowDomain("*");

      trace("Hydna Flash Hello Example");

      channel = new Channel();

      channel.addEventListener("open", function(e:Event) : void {
        trace("Connected with Hydna, sending a 'Hello'.");
        channel.write("ping");
      });

      channel.addEventListener("data", function(e:ChannelDataEvent) : void {
        trace("Data received: " + e.message);
        trace("Emitting a signal");
        channel.emit("ping");
      });

      channel.addEventListener("signal", function(e:ChannelSignalEvent) : void {
        trace("Signal received: " + e.message);
        trace("Now closing");
        channel.close();
      });

      channel.addEventListener("error", function(e:ErrorEvent) : void {
        trace("An error occured: " + e.text);
      });

      channel.addEventListener("close", function(e:Event) : void {
        trace("Received close event");
      });

      channel.connect(ADDRESS, ChannelMode.READWRITEEMIT);

    }
  }
}