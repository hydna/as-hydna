// HydnaErrorEvent.as

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

  public class HydnaErrorEvent extends Event {
    
    public static const ERROR:String = "error";
    
    private var _code:Number = 0;
    private var _message:String;
    
    /**
     *  Constructor for the HydnaErrorEvent
     *
     *  @param {Number} code The error code for this event. Default is 0
     *  @param {String} message An optional message to associate with the
     *                          event.
     */
    public function HydnaErrorEvent(code:Number=0, 
                                     message:String="Unkown Error") {
      super(ERROR, false, false);
      _code = code;
      _message = message;
    }
    
    /**
     *  Gets the associated error message for this HydnaErrorEvent instance.
     *
     *  @return {String} error message.
     */
    public function get message() : String {
      return _message;
    }
    
    /**
     *  Returns the error code for this HydnaErrorEvent instance.
     *
     *  @return {Number} the error code.
     */
    public function get code() : Number {
      return _code;
    }
    
  }
  
  
}