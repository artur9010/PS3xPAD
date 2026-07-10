#include <sys/prx.h>
#include <cell/pad.h>

SYS_MODULE_INFO(XPADG, 0, 1, 1);
SYS_MODULE_START(xpadg_start);
SYS_MODULE_STOP(xpadg_stop);

int xpadg_start(uint64_t arg) {
  (void)arg;
  return CELL_OK;
}

int xpadg_stop(void) {
  return CELL_OK;
}
