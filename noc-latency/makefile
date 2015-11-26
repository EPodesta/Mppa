K1_TOOLCHAIN_DIR ?= /usr/local/k1tools
# set the target platform (hardware or simulator)
platforms := hardware

# flags
k1-lflags := -lmppaipc

# build master bin
io-bin := master
master-srcs := srcPortal/master.c srcPortal/interface_mppa.c srcPortal/common.c

# build slave bin
cluster-bin := slave
slave-srcs := srcPortal/slave.c srcPortal/interface_mppa.c srcPortal/common.c

# build image (master + slave)
# the first binary will be the one booted on the IO!
multibin-objs := master slave
multibin-name := noc-latency.img
mppa-bin := multibin

# must be at the end of the makefile!
include $(K1_TOOLCHAIN_DIR)/share/make/Makefile.mppaipc
