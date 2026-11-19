%module imslib

// Use the Python Stable ABI to avoid rqeuiring a specific minor version of the runtime library
%begin %{
#define Py_LIMITED_API 0x03080000
%}

%feature("autodoc", "1");     // Enables auto docstring extraction from C++ comments
%feature("docstring") "";     // Optional: ensures all functions can have docstrings

%{
#include "AcoustoOptics.h"
#include "Containers.h"
#include "ImageProject.h"
#include "LibVersion.h"
#include "ConnectionList.h"
#include "IConnectionSettings.h"
#include "CS_ETH.h"
#include "CS_RS422.h"
#include "IEventHandler.h"
#include "IMSSystem.h"
#include "IMSTypeDefs.h"
#include "Auxiliary.h"
#include "Image.h"
#include "ImageOps.h"
#include "FileSystem.h"
#include "Compensation.h"
#include "ToneBuffer.h"
#include "SignalPath.h"
#include "SystemFunc.h"
#include "Diagnostics.h"
#include "VCO.h"
#include "FirmwareUpgrade.h"

#include <sstream>
#include <iomanip>

  using namespace iMS;
%}

%include "stdint.i"
%include <std_string.i>
%include <std_vector.i>
//%include <memory.i>
// %include "std_deque.i"
%include "std_map.i"
// %include "windows.i"
%include <std_array.i>
%include "attribute.i"
%include "typemaps.i"
%include "std_shared_ptr.i"

// Type hints in imslib.py (SWIG -typehints). SWIG's default hint for a wrapped class is
// typing.Any: name the Python proxy class instead. Types that Python sees differently from C++
// (custom in/out typemaps, shared_ptr) have their own pytyping typemap next to them.
%typemap(pytyping) SWIGTYPE, SWIGTYPE *, SWIGTYPE &, SWIGTYPE &&, SWIGTYPE *const& "$pytypename"
%typemap(pytyping) PyObject * "typing.Any"

// A std::shared_ptr to a %shared_ptr class is the proxy class itself in Python
%define SHARED_PTR_TYPEHINT(TYPE, PYNAME)
%typemap(pytyping) std::shared_ptr< TYPE >, std::shared_ptr< TYPE > &, std::shared_ptr< TYPE > *,
                   std::shared_ptr< const TYPE >, std::shared_ptr< const TYPE > &, std::shared_ptr< const TYPE > * "PYNAME"
%enddef

// A std::vector passed by value or by const reference takes the proxy class or any Python
// sequence, and one returned that way is copied into a tuple
%define SEQUENCE_TYPEHINT(TYPE, PYNAME, PYITEM)
%typemap(pytyping, out="typing.Tuple[PYITEM, ...]") TYPE, const TYPE & "typing.Union[PYNAME, typing.Sequence[PYITEM]]"
%enddef

// The overloads of these library methods return different types, and SWIG annotates an overloaded
// method with the return type of just one of them
%feature("python:annotations", "0") std::vector::__getitem__;
%feature("python:annotations", "0") std::vector::insert;
%feature("python:annotations", "0") std::array::__getitem__;
%feature("python:annotations", "0") std::map::erase;

%include "ims_std_chrono.i"

%template(ByteVector) std::vector<uint8_t>;
%template(StringVector) std::vector<std::string>;
%template(UUID) std::array<uint8_t, 16>;
%template(VelGain) std::array<int16_t, 2>;

SEQUENCE_TYPEHINT(std::vector<uint8_t>, ByteVector, int)
SEQUENCE_TYPEHINT(std::vector<std::string>, StringVector, str)

// A hint inside a class body cannot name a type that a member of that class is also called
// (SequenceEntry.UUID, DDSScriptRegister.bytes): those hints use these aliases
%pythoncode %{
_UUID = UUID
_bytes = bytes
%}

%shared_ptr(iMS::IMSSystem);
SHARED_PTR_TYPEHINT(iMS::IMSSystem, IMSSystem)

// Print UUID in friendly format
%extend std::array<uint8_t, 16> {
        std::string __str__() {
            std::ostringstream oss;
            oss << "[";
            oss << std::hex << std::setfill('0');
            for (int i=0; i<=3; i++) oss << std::setw(2) << static_cast<unsigned>($self->at(i));
            oss << "-";
            for (int i=4; i<=5; i++) oss << std::setw(2) << static_cast<unsigned>($self->at(i));
            oss << "-";
            for (int i=6; i<=7; i++) oss << std::setw(2) << static_cast<unsigned>($self->at(i));
            oss << "-";
            for (int i=8; i<=9; i++) oss << std::setw(2) << static_cast<unsigned>($self->at(i));
            oss << "-";
            for (int i=10; i<=15; i++) oss << std::setw(2) << static_cast<unsigned>($self->at(i));
            oss << "]";
            return oss.str();
        }
}

%rename(UUID_Stream) operator<<(std::ostream& stream, const std::array<uint8_t, 16>&);
%inline %{
    std::ostream& operator <<(std::ostream& stream, const std::array<uint8_t, 16>& uuid) {
        stream << "[";
        stream << std::hex << std::setfill('0');
        for (int i=0; i<=3; i++) stream << std::setw(2) << static_cast<unsigned>(uuid[i]);
        stream << "-";
        for (int i=4; i<=5; i++) stream << std::setw(2) << static_cast<unsigned>(uuid[i]);
        stream << "-";
        for (int i=6; i<=7; i++) stream << std::setw(2) << static_cast<unsigned>(uuid[i]);
        stream << "-";
        for (int i=8; i<=9; i++) stream << std::setw(2) << static_cast<unsigned>(uuid[i]);
        stream << "-";
        for (int i=10; i<=15; i++) stream << std::setw(2) << static_cast<unsigned>(uuid[i]);
        stream << "]";
        return stream;
    }    
%}

%template(AnalogData) std::map<int, iMS::Percent>;
%template(AnalogDataStr) std::map<std::string, iMS::Percent>;

#define _STATIC_IMS

%include "Containers.i"
%include "LibVersion.i"
%include "IMSTypeDefs.i"
%include "IEventHandler.i"
%include "IMSSystem.i"
%include "ConnectionList.i"
%include "FileSystem.i"
%include "AcoustoOptics.i"
%include "Auxiliary.i"
%include "Image.i"
%include "ImageOps.i"
%include "Compensation.i"
%include "ToneBuffer.i"
%include "ImageProject.i"
%include "SignalPath.i"
%include "SystemFunc.i"
%include "Diagnostics.i"
%include "FirmwareUpgrade.i"