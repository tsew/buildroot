################################################################################
#
# grub2
#
################################################################################

TRUSTEDGRUB2_VERSION = 2.0
TRUSTEDGRUB2_SITE = git@github.com:albal/TrustedGRUB2.git
TRUSTEDGRUB2_SITE_METHOD = git
TRUSTEDGRUB2_LICENSE = GPLv3+
TRUSTEDGRUB2_LICENSE_FILES = COPYING
TRUSTEDGRUB2_DEPENDENCIES = host-bison host-flex

TRUSTEDGRUB2_BUILTIN_MODULES = $(call qstrip,$(BR2_TARGET_TRUSTEDGRUB2_BUILTIN_MODULES))
TRUSTEDGRUB2_BUILTIN_CONFIG = $(call qstrip,$(BR2_TARGET_TRUSTEDGRUB2_BUILTIN_CONFIG))
TRUSTEDGRUB2_BOOT_PARTITION = $(call qstrip,$(BR2_TARGET_TRUSTEDGRUB2_BOOT_PARTITION))

ifeq ($(BR2_TARGET_TRUSTEDGRUB2_I386_PC),y)
TRUSTEDGRUB2_IMAGE = $(BINARIES_DIR)/grub.img
TRUSTEDGRUB2_CFG = $(TARGET_DIR)/boot/grub/grub.cfg
TRUSTEDGRUB2_PREFIX = ($(TRUSTEDGRUB2_BOOT_PARTITION))/boot/grub
TRUSTEDGRUB2_TUPLE = i386-pc
TRUSTEDGRUB2_TARGET = i386
TRUSTEDGRUB2_PLATFORM = pc
else ifeq ($(BR2_TARGET_TRUSTEDGRUB2_I386_EFI),y)
TRUSTEDGRUB2_IMAGE = $(BINARIES_DIR)/efi-part/EFI/BOOT/bootia32.efi
TRUSTEDGRUB2_CFG = $(BINARIES_DIR)/efi-part/EFI/BOOT/grub.cfg
TRUSTEDGRUB2_PREFIX = /EFI/BOOT
TRUSTEDGRUB2_TUPLE = i386-efi
TRUSTEDGRUB2_TARGET = i386
TRUSTEDGRUB2_PLATFORM = efi
else ifeq ($(BR2_TARGET_TRUSTEDGRUB2_X86_64_EFI),y)
TRUSTEDGRUB2_IMAGE = $(BINARIES_DIR)/efi-part/EFI/BOOT/bootx64.efi
TRUSTEDGRUB2_CFG = $(BINARIES_DIR)/efi-part/EFI/BOOT/grub.cfg
TRUSTEDGRUB2_PREFIX = /EFI/BOOT
TRUSTEDGRUB2_TUPLE = x86_64-efi
TRUSTEDGRUB2_TARGET = x86_64
TRUSTEDGRUB2_PLATFORM = efi
endif

# Grub2 is kind of special: it considers CC, LD and so on to be the
# tools to build the native tools (i.e to be executed on the build
# machine), and uses TARGET_CC, TARGET_CFLAGS, TARGET_CPPFLAGS to
# build the bootloader itself.

#TRUSTEDGRUB2_AUTORECONF = YES

define TRUSTEDGRUB2_RUN_AUTOGEN
        cd $(@D) && PATH=$(BR_PATH) ./autogen.sh 
endef


TRUSTEDGRUB2_PRE_CONFIGURE_HOOKS += TRUSTEDGRUB2_RUN_AUTOGEN

TRUSTEDGRUB2_CONF_ENV = \
	$(HOST_CONFIGURE_OPTS) \
	CPP="$(HOSTCC) -E" \
	TARGET_CC="$(TARGET_CC)" \
	TARGET_CFLAGS="$(TARGET_CFLAGS)" \
	TARGET_CPPFLAGS="$(TARGET_CPPFLAGS)"

#         --exec-prefix=$(HOST_DIR) \
#                 --program-prefix=$(HOST_DIR) \
#

TRUSTEDGRUB2_CONF_OPTS = \
	--prefix=$(HOST_DIR) \
	--disable-nls \
	--target=$(TRUSTEDGRUB2_TARGET) \
	--with-platform=$(TRUSTEDGRUB2_PLATFORM) \
	--disable-grub-mkfont \
	--enable-efiemu=no \
	--enable-liblzma=no \
	--enable-device-mapper=yes \
	--enable-libzfs=no \
	--disable-werror 

# We don't want all the native tools and Grub2 modules to be installed
# in the target. So we in fact install everything into the host
# directory, and the image generation process (below) will use the
# grub-mkimage tool and Grub2 modules from the host directory.

TRUSTEDGRUB2_INSTALL_TARGET_OPTS =  DESTDIR=$(HOST_DIR) install

define TRUSTEDGRUB2_IMAGE_INSTALLATION
	mkdir -p $(dir $(TRUSTEDGRUB2_IMAGE))
	$(HOST_DIR)/usr/bin/grub-mkimage \
		-d $(HOST_DIR)/usr/lib/grub/$(TRUSTEDGRUB2_TUPLE) \
		-O $(TRUSTEDGRUB2_TUPLE) \
		-o $(TRUSTEDGRUB2_IMAGE) \
		-p "$(TRUSTEDGRUB2_PREFIX)" \
		$(if $(TRUSTEDGRUB2_BUILTIN_CONFIG),-c $(TRUSTEDGRUB2_BUILTIN_CONFIG)) \
		$(TRUSTEDGRUB2_BUILTIN_MODULES)
	mkdir -p $(dir $(TRUSTEDGRUB2_CFG))
	$(INSTALL) -D -m 0644 boot/grub2/grub.cfg $(TRUSTEDGRUB2_CFG)
	# Fix strangeness with shared items by copying them back
	mkdir -p $(HOST_DIR)/share/grub
	cp $(HOST_DIR)$(HOST_DIR)/share/grub/grub-mkconfig_lib $(HOST_DIR)/share/grub/.
endef
TRUSTEDGRUB2_POST_INSTALL_TARGET_HOOKS += TRUSTEDGRUB2_IMAGE_INSTALLATION

ifeq ($(TRUSTEDGRUB2_PLATFORM),efi)
define TRUSTEDGRUB2_EFI_STARTUP_NSH
	echo $(notdir $(TRUSTEDGRUB2_IMAGE)) > \
		$(BINARIES_DIR)/efi-part/startup.nsh
endef
TRUSTEDGRUB2_POST_INSTALL_TARGET_HOOKS += TRUSTEDGRUB2_EFI_STARTUP_NSH
endif

$(eval $(autotools-package))
