#ifndef PS3XPAD_PSL1GHT_COMPAT_H
#define PS3XPAD_PSL1GHT_COMPAT_H

#include <stdint.h>
#include <stddef.h>
#include <ppu-lv2.h>
#include <sys/thread.h>
#include <sys/mutex.h>
#include <sys/systime.h>
#include <sys/prx.h>
#include <sys/process.h>
#include <sysmodule/sysmodule.h>
#include <io/pad.h>
#include <usb/usb.h>

#ifndef CELL_OK
#define CELL_OK 0
#endif

#define SYS_MODULE_INFO(name, attr, major, minor)
#define SYS_MODULE_START(fn) int module_start(uint64_t arg) __attribute__((alias(#fn)));
#define SYS_MODULE_STOP(fn) int module_stop(void) __attribute__((alias(#fn)));

typedef sysPrxId sys_prx_id_t;

#define system_call_1 lv2syscall1
#define system_call_4 lv2syscall4

#define SYS_PPU_THREAD_CREATE_JOINABLE THREAD_JOINABLE
#define sys_ppu_thread_create(threadid, entry, arg, priority, stacksize, flags, name) \
  sysThreadCreate((threadid), (void (*)(void *))(entry), (void *)(uintptr_t)(arg), (priority), (stacksize), (flags), (char *)(name))
#define sys_ppu_thread_join sysThreadJoin
#define sys_ppu_thread_exit(val) do { lv2syscall1(41, (u64)(val)); for (;;) {} } while (0)

typedef sys_mutex_attr_t sys_mutex_attribute_t;
#define sys_mutex_attribute_initialize sysMutexAttrInitialize
#define sys_mutex_create sysMutexCreate
#define sys_mutex_destroy sysMutexDestroy
#define sys_mutex_lock sysMutexLock
#define sys_mutex_unlock sysMutexUnlock

#define sys_timer_usleep sysUsleep
#define sys_timer_sleep sysSleep

#define CELL_PAD_MAX_PORT_NUM MAX_PORT_NUM
#define CELL_PAD_OK PAD_OK
#define CELL_PAD_STATUS_ASSIGN_CHANGES (1 << 1)
#define CELL_PAD_SETTING_PRESS_ON PAD_SETTINGS_PRESS_ON
#define CELL_PAD_SETTING_SENSOR_ON PAD_SETTINGS_SENSOR_ON
#define CELL_PAD_LDD_INSERT_DATA_INTO_GAME_MODE_ON 1

#define CELL_PAD_BTN_OFFSET_DIGITAL1 PAD_BUTTON_OFFSET_DIGITAL1
#define CELL_PAD_BTN_OFFSET_DIGITAL2 PAD_BUTTON_OFFSET_DIGITAL2
#define CELL_PAD_BTN_OFFSET_ANALOG_RIGHT_X PAD_BUTTON_OFFSET_ANALOG_RIGHT_X
#define CELL_PAD_BTN_OFFSET_ANALOG_RIGHT_Y PAD_BUTTON_OFFSET_ANALOG_RIGHT_Y
#define CELL_PAD_BTN_OFFSET_ANALOG_LEFT_X PAD_BUTTON_OFFSET_ANALOG_LEFT_X
#define CELL_PAD_BTN_OFFSET_ANALOG_LEFT_Y PAD_BUTTON_OFFSET_ANALOG_LEFT_Y
#define CELL_PAD_BTN_OFFSET_PRESS_RIGHT PAD_BUTTON_OFFSET_PRESS_RIGHT
#define CELL_PAD_BTN_OFFSET_PRESS_LEFT PAD_BUTTON_OFFSET_PRESS_LEFT
#define CELL_PAD_BTN_OFFSET_PRESS_UP PAD_BUTTON_OFFSET_PRESS_UP
#define CELL_PAD_BTN_OFFSET_PRESS_DOWN PAD_BUTTON_OFFSET_PRESS_DOWN
#define CELL_PAD_BTN_OFFSET_PRESS_TRIANGLE PAD_BUTTON_OFFSET_PRESS_TRIANGLE
#define CELL_PAD_BTN_OFFSET_PRESS_CIRCLE PAD_BUTTON_OFFSET_PRESS_CIRCLE
#define CELL_PAD_BTN_OFFSET_PRESS_CROSS PAD_BUTTON_OFFSET_PRESS_CROSS
#define CELL_PAD_BTN_OFFSET_PRESS_SQUARE PAD_BUTTON_OFFSET_PRESS_SQUARE
#define CELL_PAD_BTN_OFFSET_PRESS_L1 PAD_BUTTON_OFFSET_PRESS_L1
#define CELL_PAD_BTN_OFFSET_PRESS_R1 PAD_BUTTON_OFFSET_PRESS_R1
#define CELL_PAD_BTN_OFFSET_PRESS_L2 PAD_BUTTON_OFFSET_PRESS_L2
#define CELL_PAD_BTN_OFFSET_PRESS_R2 PAD_BUTTON_OFFSET_PRESS_R2
#define CELL_PAD_BTN_OFFSET_SENSOR_X PAD_BUTTON_OFFSET_SENSOR_X
#define CELL_PAD_BTN_OFFSET_SENSOR_Y PAD_BUTTON_OFFSET_SENSOR_Y
#define CELL_PAD_BTN_OFFSET_SENSOR_Z PAD_BUTTON_OFFSET_SENSOR_Z
#define CELL_PAD_BTN_OFFSET_SENSOR_G PAD_BUTTON_OFFSET_SENSOR_G

#define CELL_PAD_CTRL_LEFT PAD_CTRL_LEFT
#define CELL_PAD_CTRL_DOWN PAD_CTRL_DOWN
#define CELL_PAD_CTRL_RIGHT PAD_CTRL_RIGHT
#define CELL_PAD_CTRL_UP PAD_CTRL_UP
#define CELL_PAD_CTRL_START PAD_CTRL_START
#define CELL_PAD_CTRL_R3 PAD_CTRL_R3
#define CELL_PAD_CTRL_L3 PAD_CTRL_L3
#define CELL_PAD_CTRL_SELECT PAD_CTRL_SELECT
#define CELL_PAD_CTRL_SQUARE PAD_CTRL_SQUARE
#define CELL_PAD_CTRL_CROSS PAD_CTRL_CROSS
#define CELL_PAD_CTRL_CIRCLE PAD_CTRL_CIRCLE
#define CELL_PAD_CTRL_TRIANGLE PAD_CTRL_TRIANGLE
#define CELL_PAD_CTRL_R1 PAD_CTRL_R1
#define CELL_PAD_CTRL_L1 PAD_CTRL_L1
#define CELL_PAD_CTRL_R2 PAD_CTRL_R2
#define CELL_PAD_CTRL_L2 PAD_CTRL_L2
#define CELL_PAD_CTRL_LDD_PS (1 << 0)

typedef padInfo2 CellPadInfo2;
typedef padData CellPadData;

#define cellPadGetInfo2 ioPadGetInfo2
#define cellPadSetPortSetting ioPadSetPortSetting
#define cellPadLddGetPortNo ioPadLddGetPortNo
#define cellPadLddDataInsert ioPadLddDataInsert
#define cellPadLddUnregisterController ioPadLddUnregisterController

typedef usbLddOps CellUsbdLddOps;
typedef usbDeviceDescriptor UsbDeviceDescriptor;
typedef usbConfigurationDescriptor UsbConfigurationDescriptor;
typedef usbInterfaceDescriptor UsbInterfaceDescriptor;
typedef usbEndpointDescriptor UsbEndpointDescriptor;

#define USB_DESCRIPTOR_TYPE_CONFIGURATION USB_DESCRIPTOR_TYPE_CONFIG

#define CELL_USBD_PROBE_FAILED USB_PROBE_FAILED
#define CELL_USBD_ATTACH_FAILED USB_ATTACH_FAILED
#define CELL_USBD_DETACH_FAILED USB_DETACH_FAILED
#define CELL_USBD_PROBE_SUCCEEDED USB_PROBE_SUCCEEDED
#define CELL_USBD_ATTACH_SUCCEEDED USB_ATTACH_SUCCEEDED
#define CELL_USBD_DETACH_SUCCEEDED USB_DETACH_SUCCEEDED

#define cellUsbdRegisterExtraLdd usbRegisterExtraLdd
#define cellUsbdUnregisterExtraLdd usbUnregisterExtraLdd
#define cellUsbdOpenPipe usbOpenPipe
#define cellUsbdInterruptTransfer usbInterruptTransfer
#define cellUsbdScanStaticDescriptor usbScanStaticDescriptor
#define cellUsbdSetPrivateData usbSetPrivateData
#define cellUsbdGetPrivateData usbGetPrivateData
#define cellUsbdSetConfiguration usbSetConfiguration
#define cellUsbdSetInterface usbSetInterface

#endif
