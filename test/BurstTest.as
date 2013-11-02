
package {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.errors.IOError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;

  import hydna.net.ChannelOpenEvent;
  import hydna.net.ChannelErrorEvent;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelSignalEvent;
  import hydna.net.Channel;
  import hydna.net.ChannelMode;
  import hydna.net.URLParser;

  public class BurstTest extends Test {

    private static const MESSAGES:Number = 100;

    private var channel:Channel;


    public function BurstTest () {
      super("BurstTest");
    }


    override protected function setup () : void {
      channel = createChannel(ChannelMode.READWRITE);
      channel.addEventListener(ChannelOpenEvent.OPEN, function (e:Event) : void {
        setupDone();
      });
    }


    override protected function run () : void {
      var data:String = "djasdkjsajdlkasjdjaskldjlkasjdkasjkldjaskljdklasj";
      var count:Number = MESSAGES;

      appendLog("Burst done");

      channel.addEventListener(ChannelDataEvent.DATA,
        function (e:ChannelDataEvent) : void {
          if (--count == 0) {
            runDone();
          }
        }
      );

      for (var i:Number = 0; i < MESSAGES; i++) {
        channel.write(data);
      }
    }
  }

}