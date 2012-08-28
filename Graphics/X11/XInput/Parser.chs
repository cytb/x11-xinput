{-# LANGUAGE TypeFamilies #-}

module Graphics.X11.XInput.Parser where

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

import Graphics.X11.XInput.Types

class Struct a where
  type Pointer a
  peekStruct :: Pointer a -> IO a

instance Struct DeviceInfo where
  type Pointer DeviceInfo = DeviceInfoPtr

  peekStruct ptr = do
    id <- {# get XIDeviceInfo->deviceid #} ptr
    namePtr <- {# get XIDeviceInfo->name #} ptr
    name <- peekCString namePtr
    use <- int2deviceType <$> {# get XIDeviceInfo->use #} ptr
    att <- {# get XIDeviceInfo->attachment #} ptr
    on <- toBool <$> {# get XIDeviceInfo->enabled #} ptr
    ncls <- fromIntegral <$> {# get XIDeviceInfo->num_classes #} ptr
    clsptr <- {# get XIDeviceInfo->classes #} ptr
    classesPtrs <- peekArray ncls clsptr
    classes <- forM classesPtrs (peekStruct . castPtr)
    return $ DeviceInfo id name use att on ncls classes

instance Struct GDeviceClass where
  type Pointer GDeviceClass = GDeviceClassPtr

  peekStruct ptr = do
    tp <- (toEnum . fromIntegral) <$> {# get XIAnyClassInfo->type #} ptr
    src <- {# get XIAnyClassInfo->sourceid #} ptr
    cls <- case tp of
             XIButtonClass   -> peekButtonClass ptr
             XIKeyClass      -> peekKeyClass ptr
             XIValuatorClass -> peekValuatorClass ptr
    return $ GDeviceClass tp (fromIntegral src) cls

instance Struct ButtonState where
  type Pointer ButtonState = GDeviceClassPtr

  peekStruct ptr = do
    n <- {# get XIButtonClassInfo->state.mask_len #} ptr
    maskPtr <- {# get XIButtonClassInfo->state.mask #} ptr
    mask <- peekCStringLen (castPtr maskPtr, fromIntegral n)
    return $ ButtonState (fromIntegral n) mask

peekButtonClass :: GDeviceClassPtr -> IO DeviceClass
peekButtonClass ptr = do
  n <- {# get XIButtonClassInfo->num_buttons #} ptr
  labelsPtr <- {# get XIButtonClassInfo->labels #} ptr
  labels <- peekArray (fromIntegral n) labelsPtr
  st <- peekStruct ptr
  return $ ButtonClass (fromIntegral n) (map fromIntegral labels) st

peekKeyClass :: GDeviceClassPtr -> IO DeviceClass
peekKeyClass ptr = do
  n <- {# get XIKeyClassInfo->num_keycodes #} ptr
  kptr <- {# get XIKeyClassInfo->keycodes #} ptr
  keycodes <- peekArray (fromIntegral n) kptr
  return $ KeyClass (fromIntegral n) (map fromIntegral keycodes)

peekValuatorClass :: GDeviceClassPtr -> IO DeviceClass
peekValuatorClass ptr = ValuatorClass 
  <$> (fromIntegral <$> {# get XIValuatorClassInfo->number #} ptr)
  <*> (fromIntegral <$> {# get XIValuatorClassInfo->label #} ptr)
  <*> (realToFrac <$> {# get XIValuatorClassInfo->min #} ptr)
  <*> (realToFrac <$> {# get XIValuatorClassInfo->max #} ptr)
  <*> (realToFrac <$> {# get XIValuatorClassInfo->value #} ptr)
  <*> (fromIntegral <$> {# get XIValuatorClassInfo->resolution #} ptr)
  <*> (fromIntegral <$> {# get XIValuatorClassInfo->mode #} ptr)

instance Struct Int where
  type Pointer Int = Ptr CInt
  peekStruct x = fromIntegral <$> peek x

get_event_type :: X11.XEventPtr -> IO X11.EventType
get_event_type ptr = fromIntegral <$> {# get XEvent->type #} ptr

get_event_extension :: X11.XEventPtr -> IO CInt
get_event_extension ptr = {# get XGenericEvent->extension #} ptr

instance Struct EventCookie where
  type Pointer EventCookie = EventCookiePtr

  peekStruct xev = do
    ext    <- {# get XGenericEventCookie->extension #} xev
    et     <- {# get XGenericEventCookie->evtype #} xev
    cookie <- {# get XGenericEventCookie->cookie #} xev
    cdata  <- {# get XGenericEventCookie->data #}   xev
    return $ EventCookie {
               ecExtension = ext,
               ecType   = int2eventType et,
               ecCookie = cookie,
               ecData   = cdata }

getXGenericEventCookie :: X11.XEventPtr -> IO EventCookie
getXGenericEventCookie = peekStruct . castPtr

instance Struct DeviceEvent where
  type Pointer DeviceEvent = DeviceEventPtr

  peekStruct de = DeviceEvent 
    <$> {# get XIDeviceEvent->extension #} de
    <*> {# get XIDeviceEvent->type #}      de
    <*> {# get XIDeviceEvent->deviceid #}  de
    <*> {# get XIDeviceEvent->sourceid #}  de
    <*> {# get XIDeviceEvent->detail #}    de
    <*> (fromIntegral <$> ({# get XIDeviceEvent->root #}  de))
    <*> (fromIntegral <$> ({# get XIDeviceEvent->event #} de))
    <*> (fromIntegral <$> ({# get XIDeviceEvent->child #} de))
    <*> {# get XIDeviceEvent->root_x #}    de
    <*> {# get XIDeviceEvent->root_y #}    de
    <*> {# get XIDeviceEvent->event_x #}   de
    <*> {# get XIDeviceEvent->event_y #}   de
    <*> {# get XIDeviceEvent->flags #}     de