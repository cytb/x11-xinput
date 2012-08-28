
module Graphics.X11.XInput.Types where

#include <X11/Xlib.h>
#include <X11/extensions/XInput2.h>

import Control.Applicative
import Control.Monad
import Data.Bits
import Foreign.C
import Foreign.Ptr
import Foreign.Storable
import Foreign.Marshal.Alloc
import Foreign.Marshal.Array
import Text.Printf
import qualified Graphics.X11 as X11
import Graphics.X11.Xlib.Extras

genericEvent :: X11.EventType
genericEvent = 35

type Opcode = CInt

data EventCookie = EventCookie {
  ecExtension :: CInt,
  ecType      :: EventType,
  ecCookie    :: CUInt,
  ecData      :: Ptr () }

data DeviceEvent = DeviceEvent {
  deExtension :: CInt,
  deType      :: CInt,
  deDeviceId  :: CInt,
  deSourceId  :: CInt,
  deDetail    :: CInt,
  deRoot      :: X11.Window,
  deEvent     :: X11.Window,
  deChild     :: X11.Window,
  deRootX     :: CDouble,
  deRootY     :: CDouble,
  deEventX    :: CDouble,
  deEventY    :: CDouble,
  deFlags     :: CInt }

data EventType =
    XI_DeviceChanged      --         1
  | XI_KeyPress           --         2
  | XI_KeyRelease         --         3
  | XI_ButtonPress        --         4
  | XI_ButtonRelease      --         5
  | XI_Motion             --         6
  | XI_Enter              --         7
  | XI_Leave              --         8
  | XI_FocusIn            --         9
  | XI_FocusOut           --         10
  | XI_HierarchyChanged   --         11
  | XI_PropertyEvent      --         12
  | XI_RawKeyPress        --         13
  | XI_RawKeyRelease      --         14
  | XI_RawButtonPress     --         15
  | XI_RawButtonRelease   --         16
  | XI_RawMotion          --         17
  deriving (Eq, Show, Ord, Enum)

eventType2int :: EventType -> CInt
eventType2int et = fromIntegral $ fromEnum et + 1

int2eventType :: CInt -> EventType
int2eventType n = toEnum (fromIntegral n - 1)

data EventMask =
    XI_DeviceChangedMask    --       (1 << XI_DeviceChanged)
  | XI_KeyPressMask         --       (1 << XI_KeyPress)
  | XI_KeyReleaseMask       --       (1 << XI_KeyRelease)
  | XI_ButtonPressMask      --       (1 << XI_ButtonPress)
  | XI_ButtonReleaseMask    --       (1 << XI_ButtonRelease)
  | XI_MotionMask           --       (1 << XI_Motion)
  | XI_EnterMask            --       (1 << XI_Enter)
  | XI_LeaveMask            --       (1 << XI_Leave)
  | XI_FocusInMask          --       (1 << XI_FocusIn)
  | XI_FocusOutMask         --       (1 << XI_FocusOut)
  | XI_HierarchyChangedMask --       (1 << XI_HierarchyChanged)
  | XI_PropertyEventMask    --       (1 << XI_PropertyEvent)
  | XI_RawKeyPressMask      --       (1 << XI_RawKeyPress)
  | XI_RawKeyReleaseMask    --       (1 << XI_RawKeyRelease)
  | XI_RawButtonPressMask   --       (1 << XI_RawButtonPress)
  | XI_RawButtonReleaseMask --       (1 << XI_RawButtonRelease)
  | XI_RawMotionMask        --       (1 << XI_RawMotion)
  deriving (Eq, Show, Ord, Enum)

eventMask2int :: EventMask -> CInt
eventMask2int em = 1 `shiftL` (fromEnum em + 1)

{# pointer *XGenericEventCookie as EventCookiePtr -> EventCookie #}

{# pointer *XIDeviceEvent as DeviceEventPtr -> DeviceEvent #}

data DeviceType =
    XIMasterPointer   --                    1
  | XIMasterKeyboard  --                    2
  | XISlavePointer    --                    3
  | XISlaveKeyboard   --                    4
  | XIFloatingSlave   --                    5
  deriving (Eq, Show, Ord, Enum)

deviceType2int :: DeviceType -> CInt
deviceType2int dt = fromIntegral (fromEnum dt + 1)

int2deviceType :: CInt -> DeviceType
int2deviceType n = toEnum (fromIntegral n - 1)

type DeviceID = CInt

data DeviceInfo = DeviceInfo {
  diID :: DeviceID,
  diName :: String,
  diUse :: DeviceType,
  diAttachment :: DeviceID,
  diEnabled :: Bool,
  diNumClasses :: Int,
  diClasses :: [GDeviceClass]}
  deriving (Eq)

instance Show DeviceInfo where
  show x = printf "<%s #%s: %s, attached to #%s, classes: %s>"
                  (show $ diUse x)
                  (show $ diID x)
                  (diName x)
                  (show $ diAttachment x)
                  (show $ diClasses x)

{# pointer *XIDeviceInfo as DeviceInfoPtr -> DeviceInfo #}

data DeviceClassType =
    XIKeyClass
  | XIButtonClass
  | XIValuatorClass
  deriving (Eq, Show, Ord, Enum)

data GDeviceClass = GDeviceClass {
  dcType :: DeviceClassType,
  dcSourceId :: Int,
  dcSpecific :: DeviceClass }
  deriving (Eq)

instance Show GDeviceClass where
  show t = printf "<%s [%s]>" (show $ dcType t) (show $ dcSpecific t)

{# pointer *XIAnyClassInfo as GDeviceClassPtr -> GDeviceClass #}

data ButtonState = ButtonState {
    bsMaskLen :: Int,
    bsMask :: String }
  deriving (Eq, Show)

{# pointer *XIButtonState as ButtonStatePtr -> ButtonState #}

data DeviceClass =
    ButtonClass {
      dcNumButtons :: Int,
      dcLabels :: [X11.Atom],
      dcState :: ButtonState }
  | KeyClass {
      dcNumKeycodes :: Int,
      dcKeycodes :: [Int] }
  | ValuatorClass {
      dcNumber :: Int,
      dcLabel :: X11.Atom,
      dcMin :: Double,
      dcMax :: Double,
      dcValue :: Double,
      dcResolution :: Int,
      dcMode :: Int }
  deriving (Eq)

instance Show DeviceClass where
  show (ButtonClass n _ _) = printf "Buttons: %s" (show n)
  show (KeyClass n _) = printf "Keys: %s keycodes" (show n)
  show (ValuatorClass _ _ min max val _ _) =
      printf "Valuator: %.2f..%.2f, value %.2f" min max val

data SelectDevices =
    XIAllDevices
  | XIAllMasterDevices
  | OneDevice DeviceID
  deriving (Eq, Show, Ord)

selectDevices :: SelectDevices -> CInt
selectDevices XIAllDevices = 0
selectDevices XIAllMasterDevices = 1
selectDevices (OneDevice n) = n

foreign import ccall "XInput.chs.h XIQueryDevice"
  xiQueryDevice :: X11.Display -> CInt -> Ptr CInt -> IO DeviceInfoPtr

ptr2display :: Ptr () -> X11.Display
ptr2display = X11.Display . castPtr

display2ptr :: X11.Display -> Ptr ()
display2ptr (X11.Display ptr) = castPtr ptr

toBool 0 = False
toBool 1 = True

foreign import ccall "Xinput.chs.h XQueryExtension"
  xQueryExtension :: X11.Display -> CString -> Ptr CInt -> Ptr CInt -> Ptr CInt -> IO CInt

foreign import ccall "XInput.chs.h XIQueryVersion"
  xinputVersion :: X11.Display -> Ptr CInt -> Ptr CInt -> IO CInt

{# fun unsafe XGetEventData as getEventData {display2ptr `X11.Display', castPtr `EventCookiePtr'} -> `Bool' #}

{# fun unsafe XFreeEventData as freeEventData {display2ptr `X11.Display', castPtr `EventCookiePtr'} -> `()' #}

-- | XInput initialization result
data XInputInitResult =
    NoXInput                -- ^ Extension is not supported at all.
  | VersionMismatch Int Int -- ^ XInput 2.0 is not supported, but other version is.
  | InitOK Opcode           -- ^ XInput 2.0 is supported, return xi_opcode.
  deriving (Eq, Show)

