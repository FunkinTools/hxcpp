class ClientOne implements pack.HostInterface
{
   public function new() {}

   public function getOne():Int
      return 1;

   public function getOneString():String
      return "1";
}

class ClientFoo implements IFoo
{
   public function new() {}

   public function baz():String
      return "foo";
}

class Client
{
   public static var clientBool0:Bool = true;
   public static var clientBool1:Bool = false;
   public static var clientBool2:Bool = true;
   public static var clientBool3:Bool = false;

   static function fail(message:String):Void
   {
      Common.status = message;
   }

   static function checkSwitch(result:Dynamic, testName:String):Bool
   {
      switch result {
         case Error(message):
            fail('Failed $testName: $message');
            return false;
         default:
            return true;
      }
   }

   public static function main():Void
   {
      Common.status = "running";

      if (sys.thread.Thread.current() == null)
      {
         fail("Cppia Thread.current not working.");
         return;
      }

      if (!validateHostImplementation())  return;
      if (!validateClientExtends())       return;
      if (!validateInterfaces())          return;
      if (!validateClientIHostImpl())     return;
      if (!validateClientExtends2())      return;
      if (!validateBoolRepresentation())  return;
      if (!validateLocalFunctionExceptions()) return;
      if (!validateReturnExpressions())   return;
      if (!validateRegressions())         return;

      final extending = new ClientExtendedExtendedRoot();
      extending.addValue();

      Common.clientRoot           = extending;
      Common.clientImplementation = new ClientOne();
      Common.status               = "ok";
      Common.callback             = () -> Common.callbackSet = 2;
   }

   static function validateHostImplementation():Bool
   {
      if (Common.hostImplementation.getOne() != 1)
      {
         fail("Bad call to getOne");
         return false;
      }
      if (Common.hostImplementation.getOneString() != "1")
      {
         fail("Bad call to getOneString");
         return false;
      }
      return true;
   }

   static function validateClientExtends():Bool
   {
      final c = new ClientExtends();

      if (!c.ok())
      {
         fail("Bad client extension");
         return false;
      }
      if (c.whoStartedYou() != "HostBase")
      {
         fail("Bad class fallthrough - got " + c.whoStartedYou());
         return false;
      }
      if (c.whoOverridesYou() != "ClientExtends")
      {
         fail("Bad class override - got " + c.whoOverridesYou());
         return false;
      }
      if (!c.testPointers())
      {
         fail("Could not move native pointers");
         return false;
      }
      if (!c.testOne())
      {
         fail("Bad ClientExtends getOne");
         return false;
      }
      return true;
   }

   static function validateInterfaces():Bool
   {
      final c = new ClientExtends();

      final hostInterface:IHostInterface = c;
      if (hostInterface.whoStartedYou() != "HostBase")
      {
         fail("Bad interface fallthrough");
         return false;
      }
      if (hostInterface.whoOverridesYou() != "ClientExtends")
      {
         fail("Bad interface override");
         return false;
      }
      if (hostInterface.hostImplOnly(1, "two", 3) != "1two3")
      {
         fail("Bad hostImplOnly implementation");
         return false;
      }

      final clientInterface:IClientInterface = c;
      if (clientInterface.whoStartedYou() != "HostBase")
      {
         fail("Bad client interface fallthrough");
         return false;
      }
      if (clientInterface.uniqueClientFunc() != "uniqueClientFunc")
      {
         fail("Bad new client interface call");
         return false;
      }
      if (clientInterface.whoOverridesYou() != "ClientExtends")
      {
         fail("Bad client interface override");
         return false;
      }

      final clientHostInterface:IClientHostInterface = c;
      if (clientHostInterface.whoStartedYou() != "HostBase")
      {
         fail("Bad client/host interface fallthrough");
         return false;
      }
      if (clientHostInterface.whoOverridesYou() != "ClientExtends")
      {
         fail("Bad client/host interface override");
         return false;
      }
      if (clientHostInterface.whoAreYou() != "ClientExtends")
      {
         fail("Bad client/host interface whoAreYou");
         return false;
      }
      return true;
   }

   static function validateClientIHostImpl():Bool
   {
      final c = new ClientIHostImpl();
      if (c.hostImplOnly(0, null, 0) != "client"
       || c.whoStartedYou()    != "client"
       || c.whoOverridesYou()  != "client")
      {
         fail("Trouble implementing host interface");
         return false;
      }
      return true;
   }

   static function validateClientExtends2():Bool
   {
      final c1:ClientExtends = new ClientExtends2();
      if (c1.getGeneration() != 2)
      {
         fail("Error calling cppia super function");
         return false;
      }

      final c2 = new ClientExtends2();
      if (c2.testOne())
      {
         fail("ClientExtends2 getOne should fail");
         return false;
      }
      if (!c2.testOneExtended())
      {
         fail("ClientExtends2 testOneExtended failed");
         return false;
      }
      if (!c2.testFour())
      {
         fail("ClientExtends2 testFour error");
         return false;
      }
      return true;
   }

   static function validateBoolRepresentation():Bool
   {
      final hostBools   = '${HostBase.hostBool0}/${HostBase.hostBool1}/${HostBase.hostBool2}/${HostBase.hostBool3}';
      final clientBools = '$clientBool0/$clientBool1/$clientBool2/$clientBool3';

      if (hostBools != clientBools)
      {
         fail('Error in bool representation: $hostBools != $clientBools');
         return false;
      }
      return true;
   }

   static function validateLocalFunctionExceptions():Bool
   {
      if (!checkSwitch(LocalFunctionExceptions.testLocalCallingStatic(),    "throw in static called by local"))    return false;
      if (!checkSwitch(LocalFunctionExceptions.testCatchWithinLocal(),      "catch in local function"))            return false;
      if (!checkSwitch(LocalFunctionExceptions.testCatchFromLocal(),        "catching exception from local"))      return false;
      if (!checkSwitch(LocalFunctionExceptions.testObjMethodOnReturn(),     "object method on returned value"))    return false;
      if (!checkSwitch(LocalFunctionExceptions.testClassMethodOnReturn(),   "class method on returned value"))     return false;
      if (!checkSwitch(LocalFunctionExceptions.testHostClassMethodOnHostReturn(), "host class method on host return")) return false;
      return true;
   }

   static function validateReturnExpressions():Bool
   {
      if (!checkSwitch(ReturnExpressions.testHostThisReturn(),   "host this return stopping argument evaluation")) return false;
      if (!checkSwitch(ReturnExpressions.testHostArgReturn(),    "argument return stopping argument evaluation"))  return false;
      if (!checkSwitch(ReturnExpressions.testClientThisReturn(), "client this return stopping evaluation"))        return false;
      if (!checkSwitch(ReturnExpressions.testFuncReturn(),       "function value return stopping evaluation"))     return false;
      return true;
   }

   static function validateRegressions():Bool
   {
      var x:Dynamic = 3;
      x *= 5;
      if (x != 15)
      {
         fail('Failed regression #926: x = $x');
         return false;
      }

      var y:Int = 1290555;
      y *= 1290555;
      if (y != -915102823)
      {
         fail('Failed regression #1257: y = $y');
         return false;
      }
      return true;
   }
}
