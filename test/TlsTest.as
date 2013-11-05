
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

  public class TlsTest extends Test {

    private static const MESSAGES:Number = 10;
    private static const DATA:String = "acbdsdfjkdsfjkwejrkjkerwerewkjrjewkkp" +
                                       "vcxovxcpoopewprpweorpopsdfopfopdsofpf" +
                                       "djasdkjsajdlkasjdjaskldjlkasjdkasjkld" +
                                       "bvcmnmewrweorocxzcoxzo123,mfdskclzkxc";                                       

    private var channel:Channel;


    public function TlsTest () {
      super("TlsTest");
    }


    override protected function setup () : void {
      channel = createChannel(ChannelMode.READWRITE, null, true);
      channel.addEventListener(ChannelEvent.OPEN, function (e:Event) : void {
        setupDone();
      });
    }


    override protected function run () : void {
      var count:Number = MESSAGES;

      channel.addEventListener(ChannelEvent.DATA,
        function (e:ChannelEvent) : void {
          assertEqual(e.message, DATA);
          if (--count == 0) {
            runDone();
          }
        }
      );

      for (var i:Number = 0; i < MESSAGES; i++) {
        channel.write(DATA);
      }
    }
  }

}