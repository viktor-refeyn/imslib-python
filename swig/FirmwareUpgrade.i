%include <std_shared_ptr.i>
%include <std_string.i>
%include <exception.i>

%{
#include <filesystem>
#include <fstream>
#include <stdexcept>

namespace iMS
{
  // The C++ FirmwareUpgrade class only keeps a reference to the firmware stream, which is read from a
  // background thread for as long as the upgrade runs.  Python has no std::istream to hand over, so
  // this subclass opens the firmware file itself and owns the stream for the lifetime of the object.
  struct PyFirmwareStream
  {
    explicit PyFirmwareStream(const std::string& filename)
      // Python passes UTF-8.  MCS files are text, so open in text mode
      : m_strm(std::filesystem::u8path(filename))
    {
      if (!m_strm.is_open()) {
        throw std::runtime_error("Unable to open firmware file: " + filename);
      }
    }
    std::ifstream m_strm;
  };

  // The stream is a base class so that it is created before, and destroyed after, the FirmwareUpgrade
  // (whose destructor joins the thread that reads the stream)
  class PyFirmwareUpgrade : private PyFirmwareStream, public FirmwareUpgrade
  {
  public:
    PyFirmwareUpgrade(std::shared_ptr<IMSSystem> ims, const std::string& filename)
      : PyFirmwareStream(filename), FirmwareUpgrade(ims, m_strm) {}
  };
}
%}

namespace iMS
{
  enum class FirmwareUpgradeEvents
  {
    FIRMWARE_UPGRADE_DONE,
      FIRMWARE_UPGRADE_ERROR,
      FIRMWARE_UPGRADE_STARTED,
      FIRMWARE_UPGRADE_INITIALIZE_OK,
      FIRMWARE_UPGRADE_CHECKID_OK,
      FIRMWARE_UPGRADE_ENTER_UG_MODE,
      FIRMWARE_UPGRADE_ERASE_OK,
      FIRMWARE_UPGRADE_PROGRAM_OK,
      FIRMWARE_UPGRADE_VERIFY_OK,
      FIRMWARE_UPGRADE_LEAVE_UG_MODE
      };
}

namespace iMS
{

  class FirmwareUpgradeProgress
  {
  public:
    FirmwareUpgradeProgress(uint8_t);
    bool Started() const;
    bool InitializeOK() const;
    bool CheckIdOK() const;
    bool EnterUpgradeModeOK() const;
    bool EraseOK() const;
    bool ProgramOK() const;
    bool VerifyOK() const;
    bool LeaveUpgradeModeOK() const;
  };

  class FirmwareUpgradeError
  {
  public:
    FirmwareUpgradeError(uint8_t);
    bool StreamError() const;
    bool IdCode() const;
    bool Erase() const;
    bool Program() const;
    bool TimeOut() const;
    bool Crc() const;
  };

  // Raise OSError in Python if the firmware file cannot be opened
  %exception FirmwareUpgrade::FirmwareUpgrade {
    try {
      $action
    } catch (const std::exception& e) {
      SWIG_exception(SWIG_IOError, e.what());
    }
  }

  %nodefaultctor FirmwareUpgrade;

  class FirmwareUpgrade
  {
  public:
    // In place of the C++ constructor taking a std::istream&:
    //   FirmwareUpgrade(ims, filename)   → filename is the path to the firmware upgrade file (MCS format)
    %extend {
      FirmwareUpgrade(std::shared_ptr<IMSSystem> ims, const std::string& filename) {
        return new iMS::PyFirmwareUpgrade(ims, filename);
      }
      ~FirmwareUpgrade() {
        // Every object created from Python is a PyFirmwareUpgrade; delete it as one so that the
        // stream is released too (the C++ destructor is not virtual)
        delete static_cast<iMS::PyFirmwareUpgrade*>($self);
      }
    }

    enum class UpgradeTarget
    {
      SYNTHESISER,
	CONTROLLER
	};

    bool StartUpgrade(const UpgradeTarget target = UpgradeTarget::SYNTHESISER);
    bool VerifyIntegrity(const UpgradeTarget target = UpgradeTarget::SYNTHESISER);
    bool UpgradeDone() const;
    bool UpgradeError() const;
    FirmwareUpgradeProgress GetUpgradeProgress() const;
    FirmwareUpgradeError GetUpgradeError() const;
    uint32_t GetTransferLength() const;
    uint32_t GetTotalTransferLength() const;
    void FirmwareUpgradeEventSubscribe(const int message, IEventHandler* handler);
    void FirmwareUpgradeEventUnsubscribe(const int message, const IEventHandler* handler);
  };

}
