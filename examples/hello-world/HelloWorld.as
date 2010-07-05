package {
  
  import flash.display.Sprite;
  import flash.text.TextField;
  import com.hydna.Hydna;
  import com.hydna.HydnaAddr;
  import com.hydna.HydnaStream;
  import com.hydna.HydnaStreamMode;
  import com.hydna.HydnaStreamEvent;
  import flash.utils.ByteArray;
  
  public class HelloWorld extends Sprite {
    
    public function HelloWorld() {
      trace("HelloWorld App");
      var addr:HydnaAddr = HydnaAddr.fromHex("AABBCCDD:EEFF:2255");
      trace(addr.toString());
      
      var hydna:Hydna = Hydna.connect("127.0.0.1", 7015);
      
      var stream:HydnaStream = hydna.open(addr, HydnaStreamMode.READWRITE);
      
      stream.addEventListener(HydnaStreamEvent.OPEN, function() {
        trace("stream is now open");
        stream.writeString("Hello World!");
      });

      stream.addEventListener(HydnaStreamEvent.DATA, function(event:HydnaStreamEvent) {
        trace("recieved data: " + event.buffer);
      });
      
      trace("end of main");
    }
    
  }
  

}