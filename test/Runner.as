//-runtime-shared-libraries
// Runner.as

package {

  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.TextEvent;
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
  public class Runner extends Sprite {

    private var _output:TextField;

    private var _tests:Array;

    private var _total:Number = 0;
    private var _passed:Number = 0;
    private var _failed:Number = 0;
    

    public function Runner() {
      var channel:Channel;

      Security.allowDomain("*");

      _tests = new Array();

      _tests.push(BurstTest);
      _tests.push(SignalTest);

      _total = _tests.length;

      _output = new TextField();
      _output.multiline = true;
      _output.wordWrap = true;
      _output.width = stage.stageWidth;
      _output.height = stage.stageHeight;
      addChild(_output);

      appendLog("-- Hydna test suite for ActionScript 3 --");

      nextTest();
    }


    private function appendLog (text:String) : void {
      _output.appendText(text + "\n");
      _output.scrollV = _output.maxScrollV;
    }


    private function log (text:String) : void {
      _output.appendText(text);
      _output.scrollV = _output.maxScrollV;
    }


    private function nextTest () : void {
      var TestClass:Object;
      trace("Next test");
      if ((TestClass = _tests.pop())) {
        runTest(TestClass);
        return;
      }

      appendLog("Completed tests: "  + _total +
                ", passed: " + _passed +
                ", failed:"  + _failed);
    }


    private  function runTest (TestClass:Object) : void {
      var test:Test = new TestClass();

      test.addEventListener(Test.ERROR, function () : void {
        _failed++;
        appendLog(test.errorMessage);
        nextTest();
      });

      test.addEventListener(Test.COMPLETE, function () : void {
        _passed++;
        appendLog(test.testTime);
        nextTest();
      });

      test.addEventListener(Test.LOG, function (e:TextEvent) : void {
        log(e.text);
      });

      test.addEventListener(Test.APPEND_LOG, function (e:TextEvent) : void {
        appendLog(e.text);
      });

      log("Test " + test.name + "...");

      test.start();
    }
  }
}