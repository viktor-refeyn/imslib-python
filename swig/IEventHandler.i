// SWIG wraps the overloads as EventAction(self, *args), which type checkers reject every
// override of, as an override names its sender and message parameters
%feature("shadow") iMS::IEventHandler::EventAction %{
def EventAction(self, sender: "typing.Any", message: int, *args: "typing.Any") -> None:
    r"""
    EventAction(IEventHandler self, void * sender, int const message)
    EventAction(IEventHandler self, void * sender, int const message, int const param)
    EventAction(IEventHandler self, void * sender, int const message, int const param, int const param2)
    EventAction(IEventHandler self, void * sender, int const message, double const param)
    EventAction(IEventHandler self, void * sender, int const message, int const param, ByteVector data)
    """
    return $action(self, sender, message, *args)
%}

namespace iMS {

%feature("director") IEventHandler;
class IEventHandler
{
protected:
    IEventHandler();
 public:
  virtual ~IEventHandler();
  //		bool operator == (const IEventHandler e);
  virtual void EventAction(void* sender, const int message) {}
  virtual void EventAction(void* sender, const int message, const int param) {}
  virtual void EventAction(void* sender, const int message, const int param, const int param2) {}
  virtual void EventAction(void* sender, const int message, const double param) {}
  virtual void EventAction(void* sender, const int message, const int param, const std::vector<uint8_t> data) {}
};
 
}
