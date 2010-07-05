// HydnaStreamEvent.as

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
package com.hydna {
  
  import flash.events.Event;
  import flash.utils.ByteArray;
  
  import com.hydna.HydnaAddr;

  public class HydnaStreamEvent extends Event {
    
    public static const OPEN:String = "open";
    public static const CLOSE:String = "close";
    public static const DATA:String = "data";
    public static const ERROR:String = "error";
    
    private var _code:Number = 0;
    private var _buffer:ByteArray;
    
    public function HydnaStreamEvent(type:String, 
                                     code:Number=0, 
                                     buffer:ByteArray=null) {
      super(type, false, false);
      _code = code;
      _buffer = buffer;
    }
    
    public function get buffer() : ByteArray {
      return _buffer;
    }
    
    /**
     *  Returns the HydnaAddr for the HydnaStream that raised this Event.
     *
     *  @return {HydnaAddr} the specified HydnaAddr instance.
     */
    public function get code() : Number {
      return _code;
    }
    
  }
  
  
}