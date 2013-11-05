
package {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.TextEvent;
  import flash.events.IOErrorEvent;
  import flash.events.TimerEvent;
  import flash.errors.IOError;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.Dictionary;
  import flash.utils.Timer;

  import hydna.net.ChannelEvent;
  import hydna.net.ChannelErrorEvent;
  import hydna.net.Channel;
  import hydna.net.ChannelMode;
  import hydna.net.URLParser;

  public class Test extends EventDispatcher {

    public static const SETUP:String = "setup";
    public static const ERROR:String = "error";
    public static const COMPLETE:String = "complete";
    public static const LOG:String = "log";
    public static const APPEND_LOG:String = "appendlog";

    private var _name:String;

    private var _testTimer:Timer;

    private var _startTime:Date;
    private var _errorMessage:String;
    private var _currentPhase:String;

    private var _channels:Array;
    private var _teardownCount:Number;

    public function Test (name:String) {
      _name = name;
      _currentPhase = "NA";
      _channels = new Array();
      _testTimer = new Timer(12000, 1);
      _testTimer.addEventListener(TimerEvent.TIMER_COMPLETE, timeoutHandler);
    }


    public function get name() : String {
      return _name;
    }


    public function get errorMessage() : String {
      return "Error in phase [" + _currentPhase + "] " + _errorMessage;
    }


    public function get testTime() : String {
      var now:Date = new Date();
      var elapsed:Number = now.getTime() - _startTime.getTime();
      
      return elapsed + " sec";
    }


    public function start () : void {
      _currentPhase = "setup";
      _startTime = new Date();
      _testTimer.start();
      try {
        setup();
      } catch (err:Error) {
        raiseError(err.message);
        return;
      }
    }

    protected function createChannel (mode:Number,
                                      path:String=null,
                                      secure:Boolean=false) : Channel {
      var channel:Channel = new Channel();
      var url:String;

      url = "testing.hydna.net";

      path = path || randomPath();
      url += path;
      trace(url);
      if (secure) {
        url = 'https://' + url;
      }

      channel.connect(url, mode);
      channel.addEventListener("error", channelErrorHandler);
      channel.addEventListener(ChannelEvent.CLOSE, channelCloseHandler);
      _channels.push(channel);
      return channel;
    }


    protected function setupDone () : void {
      _currentPhase = "run";
      try {
        run();
      } catch (err:Error) {
        raiseError(err.message);
        return;
      }      
    }


    protected function runDone () : void {
      _currentPhase = "teardown";
      try {
        teardown();
      } catch (err:Error) {
        raiseError(err.message);
        return;
      }      
    }


    protected function setup () : void {
      
    }


    protected function run () : void {
      
    }


    protected function teardown () : void {
      _teardownCount = _channels.length;

      if (_teardownCount == 0) {
        complete();
        return;
      }

      for each (var channel:Channel in _channels) {
        channel.close();
      }
    }


    protected function complete () : void {
      _currentPhase = "complete";
      _testTimer.stop();
      dispatchEvent(new Event(COMPLETE));
    }


    protected function log (text:String) : void {
      dispatchEvent(new TextEvent(LOG, false, false, text));
    }


    protected function appendLog (text:String) : void {
      dispatchEvent(new TextEvent(APPEND_LOG, false, false, text));
    }


    protected function assertEqual (str1:String, str2:String) : void {
      if (str1 !== str2) {
        throw new Error("Not equal");
      }
    }


    private function channelErrorHandler (e:ChannelErrorEvent) : void {
      raiseError(e.text);
    }


    private function channelCloseHandler (e:ChannelEvent) : void {
      if (_currentPhase != "teardown") {
        raiseError("Unexpected closed");
        return;
      }

      if (--_teardownCount == 0) {
        complete();
      }
      
    }


    private function timeoutHandler (e:TimerEvent) : void {
      raiseError("TIMEOUT");
    }


    private function raiseError (message:String) : void {

      if (_errorMessage) {
        return;
      }

      _testTimer.stop();

      _errorMessage = message;
      dispatchEvent(new Event(ERROR));
    }


    private function randomPath () : String {
      var now:Date = new Date();
      var path:Array = new Array();
      var bytes:Array = new Array();

      for (var i:Number = 0; i < 20; i++) {
        bytes.push((~~(Math.random() * 255)).toString(16));
      }

      path.push(now.getTime().toString(16));
      path.push(bytes.join(''));

      return '/' + path.join('/');
    }
  }

}