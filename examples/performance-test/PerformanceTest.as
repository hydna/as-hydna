// PerformanceTest.as

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
  import flash.text.TextField;
  import flash.utils.ByteArray;

  import com.hydna.Hydna;
  import com.hydna.HydnaAddr;
  import com.hydna.HydnaDataStream;
  import com.hydna.HydnaDataStreamMode;
  import com.hydna.HydnaStreamEvent;
  
  /**
   *  Hydna Actionscript Performance Test 
   *
   *  This Application opens a Hydna stream and sends 100 000 messages over
   *  the instance. The time between each sent and received message is timed
   *  and summarized at the end.
   *
   */
  public class PerformanceTest extends Sprite {
    
    public static const HOST:String = "127.0.0.1";
    public static const PORT:Number = 7015;
    
    public static const ADDRESS:String = "AABBCCDD:EEFF:2255";
    
    public static const MESSAGE_COUNT:Number = 100000;
    public static const MESSAGE:String = "This is a performance test";
    
    public function PerformanceTest() {
      var output:TextField = new TextField();
      var hydna:Hydna;
      var stream:HydnaDataStream;
      var starttime:Number;
      var messagesReceived:Number = 0;
      
      output.width = 400;
      addChild(output);
      
      output.appendText("Hydna Actionscript Performance Test\n");
      
      hydna = Hydna.connect(HOST, PORT);
      
      stream = hydna.open(HydnaAddr.fromHex(ADDRESS), 
                          HydnaDataStreamMode.READWRITE);
      
      stream.addEventListener(HydnaStreamEvent.OPEN, 
        function() : void {
          
          output.appendText("Sending " + MESSAGE_COUNT + " messages ("
                            + MESSAGE.length + " bytes each)...\n");
              
          starttime = (new Date()).getTime();

          for (var i:Number = 0; i < MESSAGE_COUNT; i++) {
            stream.writeUTF(MESSAGE);
          }
        }
      );

      stream.addEventListener(HydnaStreamEvent.DATA, 
        function(event:HydnaStreamEvent) : void {
          if (++messagesReceived == MESSAGE_COUNT) {
            var time:Number = ((new Date()).getTime() - starttime); 
            output.appendText("Done in " + time + " milliseconds\n");
/*            hydna.close();*/
          }
        }
      );
      
    }
    
  }

}