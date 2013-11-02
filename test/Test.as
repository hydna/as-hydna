
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

  import hydna.net.ChannelOpenEvent;
  import hydna.net.ChannelCloseEvent;
  import hydna.net.ChannelErrorEvent;
  import hydna.net.ChannelDataEvent;
  import hydna.net.ChannelSignalEvent;
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

    public function Test (name:String) {
      _name = name;
      _currentPhase = "NA";
      _channels = new Array();
      _testTimer = new Timer(5000, 1);
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

    protected function createChannel (mode:Number, path:String=null) : Channel {
      var channel:Channel = new Channel();
      var url:String;

      url = "testing.hydna.net";

      if (path != null) {
        url += path;
      }

      channel.connect(url, mode);
      channel.addEventListener("error", channelErrorHandler);
      channel.addEventListener(ChannelCloseEvent.CLOSE, channelCloseHandler);
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
      _currentPhase = "complete";
      _testTimer.stop();
      dispatchEvent(new Event(COMPLETE));
    }


    protected function setup () : void {
      
    }


    protected function run () : void {
      
    }


    protected function log (text:String) : void {
      dispatchEvent(new TextEvent(LOG, false, false, text));
    }


    protected function appendLog (text:String) : void {
      dispatchEvent(new TextEvent(APPEND_LOG, false, false, text));
    }


    private function channelErrorHandler (e:ChannelErrorEvent) : void {
      raiseError(e.text);
    }


    private function channelCloseHandler (e:ChannelCloseEvent) : void {
      raiseError("Unexpected closed");
    }

    private function timeoutHandler (e:TimerEvent) : void {
      raiseError("TIMEOUT");
    }

    private function raiseError (message:String) : void {

      if (_errorMessage) {
        return;
      }

      _errorMessage = message;
      dispatchEvent(new Event(ERROR));
    }
  }

}