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
  import flash.events.MouseEvent;
  import flash.text.TextField;
  import flash.text.TextFieldAutoSize;
  import flash.utils.ByteArray;

  import com.hydna.Hydna;
  import com.hydna.HydnaAddr;
  import com.hydna.HydnaDataStream;
  import com.hydna.HydnaDataStreamMode;
  import com.hydna.HydnaStreamEvent;
  
  /**
   *  Hello world example Application
   *
   */
  public class HelloWorld extends Sprite {

    public static const HOST:String = "127.0.0.1";
    public static const PORT:Number = 7015;
    
    public static const ADDRESS:String = "AABBCCDD:EEFF:2255";
    
    public function HelloWorld() {
      var output:TextField = new TextField();
      var send:TextField = new TextField();
      var hydna:Hydna;
      var stream:HydnaDataStream;
      
      send.text = "Click to send 'Hello World' message";
      send.autoSize = TextFieldAutoSize.CENTER;
      send.background = true;
      send.backgroundColor = 0xAAAAAA;
      send.visible = false;
      send.x = 100;
      send.width = 120;
      send.addEventListener(MouseEvent.CLICK, 
        function(event:MouseEvent) : void {
          output.appendText("Sending 'Hello World!' message...\n");
          stream.writeUTF("Hello World!");
        }
      );
      addChild(send);
      
      output.y = 30;
      output.width = 400;
      output.height = 400;
      addChild(output);
      
      output.appendText("Hydna Hello World Example\n");

      hydna = Hydna.connect(HOST, PORT);
      
      stream = hydna.open(HydnaAddr.fromHex(ADDRESS), 
                          HydnaDataStreamMode.READWRITE);
      
      stream.addEventListener(Event.OPEN, 
        function() : void {
          output.appendText("Connected with Hydna Network\n");
          send.visible = true;
        }
      );

      stream.addEventListener(HydnaStreamEvent.DATA, 
        function(event:HydnaStreamEvent) : void {
          var data:String = event.buffer.readUTF();
          output.appendText("Receivied '" + data + "' from network...\n\n");
          hydna.shutdown();
        }
      );

      stream.addEventListener(Event.CLOSE, 
        function(event:Event) : void {
          output.appendText("Stream is now closed\n");
        }
      );
      
      hydna.addEventListener(Event.CLOSE, 
        function(event:Event) : void {
          output.appendText("Hydna is now closed\n\n");
        }
      );
    }
    
  }
  

}