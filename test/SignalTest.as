
package {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.errors.IOError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;

  import hydna.net.ChannelEvent;
  import hydna.net.Channel;
  import hydna.net.ChannelMode;
  import hydna.net.URLParser;

  public class SignalTest extends Test {

    private static const PING:String = "ping";

    private var channel:Channel;


    public function SignalTest () {
      super("SignalTest");
    }


    override protected function setup () : void {
      channel = createChannel(ChannelMode.READWRITEEMIT, "/ping-back");
      channel.addEventListener(ChannelEvent.OPEN,
        function (e:Event) : void {
          setupDone();
        }
      );
    }


    override protected function run () : void {
      channel.addEventListener(ChannelEvent.SIGNAL,
        function (e:ChannelEvent) : void {
          runDone();
        }
      )
      channel.emit(PING);
    }
  }

}