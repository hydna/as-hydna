
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

  public class SignalTest extends Test {

    private static const PING:String = "PING";

    private var channel:Channel;


    public function SignalTest () {
      super("SignalTest");
    }


    override protected function setup () : void {
      channel = createChannel(ChannelMode.READWRITEEMIT, "/ping-back");
      channel.addEventListener(ChannelOpenEvent.OPEN,
        function (e:Event) : void {
          setupDone();
        }
      );
    }


    override protected function run () : void {
      channel.addEventListener("signal",
        function (e:ChannelSignalEvent) {
          appendLog("emit received");
          runDone();
        }
      )
      appendLog("send emit");
      channel.emit(PING);
    }
  }

}