// PerformanceTest.as

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

package {

  import flash.display.Sprite;
  import flash.events.Event;
  import flash.text.TextField;
  import flash.utils.ByteArray;

  import hydna.net.Channel;
  import hydna.net.ChannelMode;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelSignalEvent;

  /**
   *  Hydna Actionscript Performance Test
   *
   *  This Application opens a Hydna channel and sends 100 000 messages over
   *  the instance. The time between each sent and received message is timed
   *  and summarized at the end.
   *
   */
  public class PerformanceTest extends Sprite {
    // Replace ADDRESS with your own domain
    public static const ADDRESS:String = "public.hydna.net";

    public static const MESSAGE_COUNT:Number = 10000;
    public static const MESSAGE:String = "This is a performance test!";

    public function PerformanceTest() {
      var channel:Channel;
      var starttime:Number;
      var messagesReceived:Number = 0;

      trace("Hydna Actionscript Performance Test\n");

      channel = new Channel();

      channel.addEventListener("open", function() : void {
        trace("Sending " + MESSAGE_COUNT + " messages (" +
              MESSAGE.length + " bytes each)...");

         starttime = (new Date()).getTime();

         for (var i:Number = 0; i < MESSAGE_COUNT; i++) {
           channel.write(MESSAGE);
         }
      });

      channel.addEventListener("data", function(event:ChannelDataEvent) : void {
          if (++messagesReceived == MESSAGE_COUNT) {
            var time:Number = ((new Date()).getTime() - starttime);
            trace("Done in " + time + " milliseconds\n");
            channel.close();
          }
      });

      channel.connect(ADDRESS, ChannelMode.READWRITE);
    }
  }
}