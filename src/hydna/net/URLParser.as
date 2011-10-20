
package hydna.net {

  public class URLParser {

    public static var url:String;

    public static var host:String = "";
    public static var port:String = "";
    public static var protocol:String = "";
    public static var path:String = "";
    public static var parameters:Object;

    public static function parse( url:String ) : Object
    {
      URLParser.url = url;
      var reg:RegExp = /(?P<protocol>[a-zA-Z]+) : \/\/  (?P<host>[^:\/]*) (:(?P<port>\d+))?  ((?P<path>[^?]*))? ((?P<parameters>.*))? /x;
      var results:Array = reg.exec(url);

      host = results.host;
      protocol = results.protocol;
      port = results.port;
      path = results.path;

      var auth:String = null;
      var index:Number;

      if (host && (index = host.indexOf("@")) != -1) {
        auth = host.substr(0, index);
        host = host.substr(index + 1);
      }

      var paramsStr:String = results.parameters;

      if (paramsStr != "")
      {
        parameters = null;
        parameters = new Object();

        if(paramsStr.charAt(0) == "?")
        {
            paramsStr = paramsStr.substring(1);
        }
        var params:Array = paramsStr.split("&");
        for each(var paramStr:String in params)
        {
            var param:Array = paramStr.split("=");
            parameters[param[0]] = param[1];
        }
      }

      var result:Object = {
        url : url,
        protocol : results.protocol,
        auth : auth,
        host : host,
        port : port,
        path : path.substring( 1, results.path.length ),
        paramStr: paramStr,
        parameters : parameters
      };

      return result;
    }
  }
}