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

  import hydna.net.Stream;
  import hydna.net.StreamMode;
  import hydna.net.StreamDataEvent;
  import hydna.net.StreamEmitEvent;
  
  /**
   *  Hello world example Application
   *
   */
  public class HelloWorld extends Sprite {

    public static const ADDRESS:String = "localhost:7010/x00112233";
    
    public function HelloWorld() {
      var stream:Stream;
      
      trace("Hydna Flash Hello Example");
      
      stream = new Stream();

      stream.addEventListener("error", function(e:Event) : void {
        trace("An error occured: " + e.toString());
      });

      stream.addEventListener("data", function(e:StreamDataEvent) : void {
        trace("Data received: " + e.data.readUTFBytes(e.data.length));
        trace("Emitting a signal");
        stream.emitUTFBytes("ping");
      });

      stream.addEventListener("emit", function(e:StreamEmitEvent) : void {
        trace("Signal received: " + e.data.readUTFBytes(e.data.length));
        trace("Now closing");
        stream.close();
      });

      stream.addEventListener("connect", function(e:Event) : void {
        trace("Connected with Hydna, sending a 'Hello'.");
        stream.writeUTFBytes("ping");
      });

      stream.connect(ADDRESS, StreamMode.READWRITE);
    }
  }
}